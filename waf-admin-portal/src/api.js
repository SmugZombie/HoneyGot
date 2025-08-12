const defaultBase = import.meta.env.VITE_API_BASE || 'https://localhost'

export function getConfig() {
  const raw = localStorage.getItem('wafAdminCfg')
  let cfg = raw ? JSON.parse(raw) : {}
  return {
    apiBase: cfg.apiBase || defaultBase,
    token: cfg.token || '',
    pageSize: cfg.pageSize || 100,
  }
}

export function setConfig(patch) {
  const cur = getConfig()
  const n = { ...cur, ...patch }
  localStorage.setItem('wafAdminCfg', JSON.stringify(n))
  return n
}

async function req(path, { method='GET', body, token, apiBase } = {}) {
  const url = `${apiBase.replace(/\/$/,'')}${path}`
  const headers = { 'X-Admin-Token': token }
  if (body) headers['Content-Type'] = 'application/json'
  const res = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined })
  const text = await res.text()
  let data = null
  try { data = text ? JSON.parse(text) : null } catch { data = { raw: text } }
  if (!res.ok) {
    const msg = (data && (data.error || data.detail)) || res.statusText
    throw new Error(`HTTP ${res.status}: ${msg}`)
  }
  return data
}

export const api = {
  health: (cfg) => req('/admin/health', { token: cfg.token, apiBase: cfg.apiBase }),
  canariesList: (cfg, cursor=0, count=100) => req(`/admin/canaries?cursor=${cursor}&count=${count}`, { token: cfg.token, apiBase: cfg.apiBase }),
  canariesAddHashes: (cfg, hashes=[]) => req('/admin/canaries', { method:'POST', body:{ hashes }, token: cfg.token, apiBase: cfg.apiBase }),
  canariesAddCreds: (cfg, creds=[]) => req('/admin/canaries', { method:'POST', body:{ credentials: creds }, token: cfg.token, apiBase: cfg.apiBase }),
  canariesDelete: (cfg, hashes=[], creds=[]) => req('/admin/canaries', { method:'DELETE', body:{ hashes, credentials: creds }, token: cfg.token, apiBase: cfg.apiBase }),
  bansList: (cfg, cursor=0, count=100) => req(`/admin/bans?cursor=${cursor}&count=${count}`, { token: cfg.token, apiBase: cfg.apiBase }),
  banPost: (cfg, ip, ttlSeconds) => req('/admin/ban', { method:'POST', body:{ ip, ttlSeconds }, token: cfg.token, apiBase: cfg.apiBase }),
  banGet: (cfg, ip) => req(`/admin/ban/${encodeURIComponent(ip)}`, { token: cfg.token, apiBase: cfg.apiBase }),
  banDelete: (cfg, ip) => req(`/admin/ban/${encodeURIComponent(ip)}`, { method:'DELETE', token: cfg.token, apiBase: cfg.apiBase }),
}
