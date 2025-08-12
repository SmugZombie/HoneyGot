# WAF Admin Portal (React, Vite)

A simple admin UI to view/modify **canaries** and **bans** via the WAF `/admin` API.
Served on a separate port (defaults to **http://localhost:8080**).

## Quick start
1) Ensure the WAF `/admin` endpoints are reachable from your browser and **CORS** is enabled (see below).
2) Build & run with Docker:
   ```bash
   docker build -t waf-admin-ui ./
   docker run --rm -p 8080:80 -e VITE_API_BASE="https://localhost" waf-admin-ui
   ```
   Or edit `docker-compose.yml` in your main stack to add the `admin-ui` service.
3) Open http://localhost:8080, enter your **API Base** (e.g., `https://localhost`) and **Admin Token**, then Save.

### Enabling CORS on the WAF `/admin` (recommended)
Add this in your `nginx.conf` inside the `/admin` location block:

```
location ^~ /admin {
  if ($request_method = OPTIONS) {
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods "GET,POST,DELETE,OPTIONS";
    add_header Access-Control-Allow-Headers "Content-Type,X-Admin-Token";
    add_header Access-Control-Max-Age 86400;
    return 204;
  }
  add_header Access-Control-Allow-Origin * always;
  add_header Access-Control-Allow-Headers "Content-Type,X-Admin-Token" always;

  default_type application/json;
  content_by_lua_block {
    local admin = require "admin"
    admin.handle()
  }
}
```

### Trusting TLS
If your WAF uses a self-signed cert, your browser must trust it (or you must proceed once to accept the risk) for the UI to call `https://localhost/admin`.

## Dev (optional)
```bash
npm i
npm run dev   # http://localhost:5173
```
Set `VITE_API_BASE` in a `.env.local` file or in the UI settings.
