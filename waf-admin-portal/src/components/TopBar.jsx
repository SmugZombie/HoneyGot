import React from 'react'
import { getConfig, setConfig } from '../api'

export default function TopBar({ onConfig }) {
  const [apiBase, setApiBase] = React.useState(getConfig().apiBase)
  const [token, setToken] = React.useState(getConfig().token)

  function save() {
    const n = setConfig({ apiBase, token })
    onConfig && onConfig(n)
  }

  return (
    <div className="card">
      <div className="body">
        <div className="topbar">
          <div className="row" style={{flex:1}}>
            <div className="field" style={{minWidth:320}}>
              <label>API Base <span className="small">(e.g. https://localhost)</span></label>
              <input type="text" value={apiBase} onChange={e=>setApiBase(e.target.value)} placeholder="https://localhost" />
            </div>
            <div className="field" style={{minWidth:320}}>
              <label>Admin Token</label>
              <input type="password" value={token} onChange={e=>setToken(e.target.value)} placeholder="X-Admin-Token" />
            </div>
          </div>
          <div className="btn-row">
            <button className="primary" onClick={save}>Save</button>
          </div>
        </div>
      </div>
    </div>
  )
}
