local _M = {}

local cjson = require "cjson.safe"
local waf   = require "waf"
local redmod= require "resty.redis"
local iputils = require "resty.iputils"

local redis_host = os.getenv("REDIS_HOST") or "redis"
local redis_port = tonumber(os.getenv("REDIS_PORT") or "6379")
local canary_key = os.getenv("CANARY_SET_KEY") or "honey:creds"
local ban_prefix = os.getenv("BAN_REDIS_PREFIX") or "ban:ip:"

local admin_token = os.getenv("ADMIN_TOKEN") or ""
local allow_admin_cidrs = os.getenv("ALLOW_ADMIN_CIDRS") or ""
local admin_cidrs = (function()
  local t = {}
  for token in string.gmatch(allow_admin_cidrs, "[^,%s]+") do table.insert(t, token) end
  iputils.enable_lrucache()
  return (#t > 0) and iputils.parse_cidrs(t) or {}
end)()

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
  red:set_timeout(100)
  local ok, err = red:connect(redis_host, redis_port)
  if not ok then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "redis_connect_failed", detail = err }))
    return nil
  end
  return red
end

local function json_body()
  ngx.req.read_body()
  local data = ngx.req.get_body_data() or "{}"
  return cjson.decode(data) or {}
end

local function require_admin()
  local ip = client_ip()
  if not (admin_token and #admin_token > 0) then
    ngx.status = 500
    ngx.say('{"error":"admin_token_not_set"}')
    return false
  end
  if not iputils.ip_in_cidrs(ip, admin_cidrs) then
    ngx.status = 403
    ngx.say(cjson.encode({ error = "admin_ip_forbidden", ip = ip }))
    return false
  end
  local tok = ngx.req.get_headers()["x-admin-token"]
  if tok ~= admin_token then
    ngx.status = 401
    ngx.say('{"error":"invalid_token"}')
    return false
  end
  return true
end

local function ok(data) ngx.header["Content-Type"]="application/json"; ngx.say(cjson.encode(data or { ok=true })) end

-- /admin/health
local function health()
  ok({ ok = true, time = ngx.now() })
end

-- POST /admin/canaries   { hashes:[], credentials:[{username, password}] }
local function canaries_post()
  local body = json_body()
  local red = redis_connect(); if not red then return end
  local added = 0

  if type(body.hashes) == "table" then
    for _,h in ipairs(body.hashes) do
      if type(h)=="string" and #h>0 then
        local res = red:sadd(canary_key, h)
        if res == 1 then added = added + 1 end
      end
    end
  end
  if type(body.credentials) == "table" then
    for _,c in ipairs(body.credentials) do
      local u = c.username or c.user or c.email
      local p = c.password or c.pass
      if u and p then
        local h = waf.canary_hash_of(u,p)
        local res = red:sadd(canary_key, h)
        if res == 1 then added = added + 1 end
      end
    end
  end

  ok({ added = added })
end

-- DELETE /admin/canaries   { hashes:[], credentials:[...] }
local function canaries_delete()
  local body = json_body()
  local red = redis_connect(); if not red then return end
  local removed = 0
  if type(body.hashes) == "table" then
    for _,h in ipairs(body.hashes) do
      if type(h)=="string" and #h>0 then
        local res = red:srem(canary_key, h)
        if res == 1 then removed = removed + 1 end
      end
    end
  end
  if type(body.credentials) == "table" then
    for _,c in ipairs(body.credentials) do
      local u = c.username or c.user or c.email
      local p = c.password or c.pass
      if u and p then
        local h = waf.canary_hash_of(u,p)
        local res = red:srem(canary_key, h)
        if res == 1 then removed = removed + 1 end
      end
    end
  end
  ok({ removed = removed })
end

-- GET /admin/canaries?cursor=0&count=100  (SSCAN)
local function canaries_get()
  local cursor = tonumber(ngx.var.arg_cursor or "0") or 0
  local count  = tonumber(ngx.var.arg_count or "100") or 100
  local red = redis_connect(); if not red then return end
  local res, err = red:sscan(canary_key, cursor, "COUNT", count)
  if not res then
    ngx.status = 500; ngx.say(cjson.encode({ error="sscan_failed", detail=err })); return
  end
  ok({ cursor = tonumber(res[1]), hashes = res[2] or {} })
end

-- POST /admin/ban   { ip:"1.2.3.4", ttlSeconds: 86400 }
local function ban_post()
  local body = json_body()
  local ip = body.ip
  local ttl = tonumber(body.ttlSeconds or body.ttl) or nil
  if not ip then ngx.status=400; ngx.say('{"error":"ip_required"}'); return end
  waf.ban_ip(ip, ttl)
  ok({ banned = ip, ttlSeconds = ttl or "default" })
end

-- DELETE /admin/ban/:ip
local function ban_delete(ip)
  if not ip then ngx.status=400; ngx.say('{"error":"ip_required"}'); return end
  waf.unban_ip(ip)
  ok({ unbanned = ip })
end

-- GET /admin/ban/:ip
local function ban_get(ip)
  local red = redis_connect(); if not red then return end
  local key = ban_prefix .. ip
  local val = red:get(key)
  local ttl = red:ttl(key)
  ok({ ip = ip, banned = (val == "1"), ttlSeconds = ttl })
end

-- GET /admin/bans?cursor=0&count=100  (SCAN keys)
local function bans_get()
  local cursor = tonumber(ngx.var.arg_cursor or "0") or 0
  local count  = tonumber(ngx.var.arg_count or "100") or 100
  local red = redis_connect(); if not red then return end
  local res, err = red:scan(cursor, "MATCH", ban_prefix .. "*", "COUNT", count)
  if not res then ngx.status=500; ngx.say(cjson.encode({ error="scan_failed", detail=err })); return end
  local nextc = tonumber(res[1]); local keys = res[2] or {}
  local out = {}
  for _,k in ipairs(keys) do
    local ip = k:sub(#ban_prefix+1)
    local ttl = red:ttl(k)
    table.insert(out, { ip = ip, ttlSeconds = ttl })
  end
  ok({ cursor = nextc, bans = out })
end

function _M.handle()
  if not require_admin() then return end

  local method = ngx.req.get_method()
  local uri = ngx.var.uri or ""

  if uri == "/admin/health" and method == "GET" then return health() end

  if uri == "/admin/canaries" then
    if method == "POST" then return canaries_post()
    elseif method == "DELETE" then return canaries_delete()
    elseif method == "GET" then return canaries_get()
    end
  end

  local ban_ip = uri:match("^/admin/ban/([^/]+)$")
  if uri == "/admin/ban" and method == "POST" then return ban_post()
  elseif ban_ip and method == "DELETE" then return ban_delete(ban_ip)
  elseif ban_ip and method == "GET" then return ban_get(ban_ip)
  elseif uri == "/admin/bans" and method == "GET" then return bans_get()
  end

  ngx.status = 404
  ngx.say('{"error":"not_found"}')
end

return _M
