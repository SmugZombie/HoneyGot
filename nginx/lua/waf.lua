local _M = {}
local str     = require "resty.string"
local sha256  = require "resty.sha256"

local redis_host = os.getenv("REDIS_HOST") or "redis"
local redis_port = tonumber(os.getenv("REDIS_PORT") or "6379")
local ban_ttl    = tonumber(os.getenv("BAN_TTL_SECONDS") or "604800")
local canary_key = os.getenv("CANARY_SET_KEY") or "honey:creds"
local ban_prefix = os.getenv("BAN_REDIS_PREFIX") or "ban:ip:"
local login_path_re = os.getenv("LOGIN_PATH_REGEX") or "^/login$"

-- GEO
local geo_mode   = (os.getenv("GEO_MODE") or "off"):lower()          -- off|allowlist|blocklist
local geo_codes  = os.getenv("GEO_COUNTRIES") or ""
local geo_db     = os.getenv("GEO_DB_PATH") or "/usr/local/share/geo/GeoLite2-Country.mmdb"

-- IP allowlists
local allow_admin_cidrs = os.getenv("ALLOW_ADMIN_CIDRS") or ""
local allow_ip_cidrs    = os.getenv("ALLOW_IP_CIDRS") or ""

local cjson = require "cjson.safe"
local str   = require "resty.string"
local redmod= require "resty.redis"
local iputils = require "resty.iputils"
local maxmind = require "resty.maxminddb"

-- Pre-parse CIDRs once
local admin_cidrs, allow_cidrs

local function parse_cidrs(csv)
  local t = {}
  for token in string.gmatch(csv, "[^,%s]+") do
    table.insert(t, token)
  end
  if #t == 0 then return nil end
  return iputils.parse_cidrs(t)
end

-- Fast set for GEO codes
local geo_set = {}
do
  for code in string.gmatch(geo_codes, "[^,%s]+") do
    geo_set[code:upper()] = true
  end
end

local function client_ip()
  local xff = ngx.req.get_headers()["x-forwarded-for"]
  if xff and #xff > 0 then
    local ip = xff:match("([^,%s]+)")
    if ip then return ip end
  end
  return ngx.var.remote_addr
end

local function redis_connect()
  local red = redmod:new()
  red:set_timeout(50) -- ms
  local ok, err = red:connect(redis_host, redis_port)
  if not ok then return nil, err end
  return red, nil
end

local function now() return ngx.now() end

local function ban_locally(ip, seconds)
  ngx.shared.banlist:set(ip, now() + seconds, seconds)
end
local function unban_locally(ip)
  ngx.shared.banlist:delete(ip)
end
local function is_banned_local(ip)
  local until_ts = ngx.shared.banlist:get(ip)
  return (until_ts and until_ts > now())
end

local function ban_globally(ip, seconds)
  local red, err = redis_connect()
  if not red then return false, err end
  local ok, err2 = red:setex(ban_prefix .. ip, seconds, "1")
  return ok == "OK", err2
end
local function unban_globally(ip)
  local red, err = redis_connect()
  if not red then return false, err end
  local ok, err2 = red:del(ban_prefix .. ip)
  return ok ~= nil, err2
end
local function is_banned_global(ip)
  local red, err = redis_connect()
  if not red then return false, err end
  local res, e = red:get(ban_prefix .. ip)
  if e then return false, e end
  return res == "1"
end

local function hash_canary(user, pass)
  local sha = sha256:new()
  if not sha then
    ngx.log(ngx.ERR, "failed to create sha256 context")
    return nil
  end
  sha:update((user or "") .. "\0" .. (pass or ""))
  local digest = sha:final()           -- binary
  return str.to_hex(digest)            -- hex string
end

local function is_canary(user, pass)
  local red, err = redis_connect()
  if not red then return false end
  local h = hash_canary(user, pass)
  if not h then return false end
  local ok, e = red:sismember(canary_key, h)
  if e then return false end
  return ok == 1
end

function _M.canary_hash_of(user, pass)
  return hash_canary(user, pass)
end

local function parse_login_credentials()
  ngx.req.read_body()
  local ct = ngx.req.get_headers()["content-type"] or ""
  local body = ngx.req.get_body_data() or ""

  if ct:find("application/x-www-form-urlencoded", 1, true) then
    local args = ngx.req.get_post_args()
    if not args then return nil end
    return { user = args.username or args.user or args.email,
             pass = args.password or args.pass }
  end

  if ct:find("application/json", 1, true) then
    local tbl = cjson.decode(body)
    if type(tbl) == "table" then
      return { user = tbl.username or tbl.user or tbl.email,
               pass = tbl.password or tbl.pass }
    end
  end

  return nil
end

local function mark_and_block(reason)
  ngx.header["X-Ban-Reason"] = reason or "policy"
  ngx.status = ngx.HTTP_FORBIDDEN
  ngx.say("Forbidden")
  return ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- Exported helpers for admin.lua
function _M.ban_ip(ip, seconds)
  seconds = tonumber(seconds) or ban_ttl
  ban_locally(ip, seconds)
  ban_globally(ip, seconds)
  return true
end
function _M.unban_ip(ip)
  unban_locally(ip)
  unban_globally(ip)
  return true
end
function _M.is_banned(ip)
  if is_banned_local(ip) then return true end
  local g = is_banned_global(ip)
  if g then ban_locally(ip, ban_ttl) end
  return g
end
function _M.canary_hash_of(user, pass)
  return hash_canary(user, pass)
end

function _M.init_worker()
  iputils.enable_lrucache()
  admin_cidrs = parse_cidrs(allow_admin_cidrs) or {}
  allow_cidrs = parse_cidrs(allow_ip_cidrs) or {}

  if geo_mode ~= "off" then
    local ok, err = maxmind.init(geo_db)
    if not ok then
      ngx.log(ngx.ERR, "MaxMind init failed: ", err or "unknown")
    end
  end
end

local function ip_in(cidrs, ip)
  if not cidrs or #cidrs == 0 then return false end
  return iputils.ip_in_cidrs(ip, cidrs)
end

local function geo_country(ip)
  local rec, err = maxmind.lookup(ip)
  if not rec or err then return nil end
  if rec.country and rec.country.iso_code then
    return rec.country.iso_code
  end
  if rec.registered_country and rec.registered_country.iso_code then
    return rec.registered_country.iso_code
  end
  return nil
end

function _M.access_phase()
  local ip = client_ip()

  -- Always-allow CIDRs (bypass everything)
  if ip_in(allow_cidrs, ip) then
    return
  end

  -- Ban check
  if _M.is_banned(ip) then
    return mark_and_block("global-ban")
  end

  -- GEO policy
  if geo_mode ~= "off" then
    local iso = geo_country(ip)
    if geo_mode == "allowlist" then
      if not (iso and geo_set[iso]) then
        return mark_and_block("geo-allowlist")
      end
    elseif geo_mode == "blocklist" then
      if iso and geo_set[iso] then
        return mark_and_block("geo-blocklist")
      end
    end
  end

  -- Credential canary on login POST
  local uri = ngx.var.uri or ""
  if ngx.req.get_method() == "POST" and uri:match(login_path_re) then
    local creds = parse_login_credentials()
    if creds and creds.user and creds.pass and is_canary(creds.user, creds.pass) then
      _M.ban_ip(ip, ban_ttl)
      return mark_and_block("canary-credential")
    end
  end
end

return _M
