# HoneyGot - OpenResty WAF (Credential Canary + GEO + Admin API)

This package deploys an inline WAF that:
- Blocks requests using *canary credentials* seeded by your security team
- Maintains a distributed banlist in Redis
- Supports GEO allow/block lists via MaxMind
- Exposes a minimal Admin API to manage canaries and bans

## Quick start
1. **Certificates**
   - Place your TLS cert and key in `certs/` as:
     - `fullchain.pem`
     - `privkey.pem`

2. **GeoLite2 database (optional)**
   - Download **GeoLite2-Country.mmdb** from MaxMind and place it in `geo/`.

3. **Configure origin and policy**
   - Edit `docker-compose.yml`:
     - `ORIGIN_HOST` and `ORIGIN_PORT` → your upstream site
     - `ADMIN_TOKEN` → set to a long random secret
     - `ALLOW_ADMIN_CIDRS` → your admin IP ranges
     - `GEO_MODE` and `GEO_COUNTRIES` per your policy

4. **Run**
   ```bash
   docker compose up -d --build
   docker logs -f waf
   ```

## Admin API (examples)
Replace `$TOKEN` and hostname as appropriate.

```bash
TOKEN="your-admin-token"

# Health
curl -s -H "X-Admin-Token: $TOKEN" https://your-waf/admin/health

# Add canary by plaintext (hashed on WAF)
curl -s -XPOST -H "X-Admin-Token: $TOKEN" -H "Content-Type: application/json"   -d '{"credentials":[{"username":"finance-team@example.com","password":"CorrectHorseBatteryStaple!"}]}'   https://your-waf/admin/canaries

# List canaries
curl -s -H "X-Admin-Token: $TOKEN" "https://your-waf/admin/canaries?cursor=0&count=100"

# Manually ban an IP for 24h
curl -s -XPOST -H "X-Admin-Token: $TOKEN" -H "Content-Type: application/json"   -d '{"ip":"203.0.113.55","ttlSeconds":86400}'   https://your-waf/admin/ban
```

## Compute a local canary hash (no plaintext leaves your box)
```bash
python3 tools/hash_canary.py "user@example.com" "SuperSecret!"
# → add resulting hex to Redis set via Admin API (hashes field)
```

## Notes
- Request bodies are not logged. Canary secrets are compared as SHA-256 of `username + "\0" + password`.
- Use `ALLOW_IP_CIDRS` to bypass GEO/ban checks for your corporate ranges.
- If your origin requires mTLS, add `proxy_ssl_verify on;` and mount your CA to `/etc/ssl/waf/`.
