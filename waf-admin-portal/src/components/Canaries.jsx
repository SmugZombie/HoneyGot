import React from 'react'
import { api, getConfig } from '../api'
import Pagination from './Pagination'

export default function Canaries(){
  const [cursor,setCursor] = React.useState(0)
  const [rows,setRows] = React.useState([])
  const [next,setNext] = React.useState(0)
  const [hashInput,setHashInput] = React.useState('')
  const [user,setUser] = React.useState('')
  const [pass,setPass] = React.useState('')
  const [msg,setMsg] = React.useState(null)

  async function load(c=cursor){
    try{
      const { cursor:cur, hashes } = await api.canariesList(getConfig(), c, 100)
      setRows(hashes||[]); setNext(cur)
    }catch(e){ setMsg('Error: '+e.message) }
  }
  React.useEffect(()=>{ load(0) },[])

  async function addHash(){
    try{
      const list = hashInput.split(/\s+/).filter(Boolean)
      if (list.length===0) return
      await api.canariesAddHashes(getConfig(), list)
      setHashInput(''); load(0); setCursor(0); setMsg(`Added ${list.length} hash(es)`)
    }catch(e){ setMsg('Error: '+e.message) }
  }
  async function addCred(){
    try{
      if(!user || !pass) return
      await api.canariesAddCreds(getConfig(), [{ username:user, password:pass }])
      setUser(''); setPass(''); load(0); setCursor(0); setMsg('Added 1 credential (hashed at WAF)')
    }catch(e){ setMsg('Error: '+e.message) }
  }
  async function removeSelected(){
    try{
      const list = hashInput.split(/\s+/).filter(Boolean)
      if (list.length===0) return
      await api.canariesDelete(getConfig(), list, [])
      setHashInput(''); load(0); setCursor(0); setMsg(`Removed ${list.length} hash(es)`)
    }catch(e){ setMsg('Error: '+e.message) }
  }

  return (
    <div className="card">
      <div className="body">
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
          <h2>Canaries</h2>
          <Pagination cursor={cursor} disablePrev={cursor===0} disableNext={next===0}
            onPrev={()=>{ const c=0; setCursor(c); load(c) }}
            onNext={()=>{ const c=next; setCursor(c); load(c) }} />
        </div>

        {msg && <div className="alert" style={{marginBottom:'1rem'}}>{msg}</div>}

        <div className="row">
          <div className="field" style={{flex:1}}>
            <label>Add by hash (one or more, space/newline separated)</label>
            <textarea rows="4" value={hashInput} onChange={e=>setHashInput(e.target.value)}
              style={{width:'100%',padding:'.6rem .7rem',borderRadius:'.5rem',border:'1px solid var(--line)',background:'#0b1220',color:'var(--text)'}} />
            <div className="btn-row" style={{marginTop:'.5rem'}}>
              <button className="primary" onClick={addHash}>Add hash(es)</button>
              <button onClick={removeSelected}>Remove hash(es)</button>
            </div>
          </div>

          <div className="field" style={{minWidth:280,flex:'0 0 320px'}}>
            <label>Add by plaintext (hashed at WAF)</label>
            <input type="text" placeholder="username" value={user} onChange={e=>setUser(e.target.value)} />
            <input type="password" placeholder="password" value={pass} onChange={e=>setPass(e.target.value)} />
            <div className="btn-row" style={{marginTop:'.5rem'}}>
              <button className="primary" onClick={addCred}>Add credential</button>
            </div>
            <div className="small">WAF stores only SHA-256 of <span className="kbd">username + \0 + password</span>.</div>
          </div>
        </div>

        <div className="sep"></div>

        <div style={{overflowX:'auto'}}>
          <table className="table">
            <thead><tr><th>Hash</th></tr></thead>
            <tbody>
              {rows?.length? rows.map((h,i)=>(<tr key={i}><td style={{fontFamily:'ui-monospace, Menlo, Consolas, monospace',fontSize:'.9rem'}}>{h}</td></tr>))
              : <tr><td className="small">No canaries on this page.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
