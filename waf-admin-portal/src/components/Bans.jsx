import React from 'react'
import { api, getConfig } from '../api'
import Pagination from './Pagination'

export default function Bans(){
  const [cursor,setCursor] = React.useState(0)
  const [rows,setRows] = React.useState([])
  const [next,setNext] = React.useState(0)
  const [ip,setIp] = React.useState('')
  const [ttl,setTtl] = React.useState(86400)
  const [msg,setMsg] = React.useState(null)

  async function load(c=cursor){
    try{
      const { cursor:cur, bans } = await api.bansList(getConfig(), c, 100)
      setRows(bans||[]); setNext(cur)
    }catch(e){ setMsg('Error: '+e.message) }
  }
  React.useEffect(()=>{ load(0) },[])

  async function ban(){
    try{
      if(!ip) return
      await api.banPost(getConfig(), ip, Number(ttl))
      setMsg(`Banned ${ip}`); setIp(''); load(0); setCursor(0)
    }catch(e){ setMsg('Error: '+e.message) }
  }
  async function unban(one){
    try{
      const target = one || ip
      if(!target) return
      await api.banDelete(getConfig(), target)
      setMsg(`Unbanned ${target}`); load(cursor)
    }catch(e){ setMsg('Error: '+e.message) }
  }

  return (
    <div className="card">
      <div className="body">
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
          <h2>Bans</h2>
          <Pagination cursor={cursor} disablePrev={cursor===0} disableNext={next===0}
            onPrev={()=>{ const c=0; setCursor(c); load(c) }}
            onNext={()=>{ const c=next; setCursor(c); load(c) }} />
        </div>

        {msg && <div className="alert" style={{marginBottom:'1rem'}}>{msg}</div>}

        <div className="row">
          <div className="field" style={{minWidth:240}}>
            <label>IP address</label>
            <input type="text" placeholder="203.0.113.5" value={ip} onChange={e=>setIp(e.target.value)} />
          </div>
          <div className="field" style={{minWidth:160}}>
            <label>TTL (seconds)</label>
            <input type="number" min="0" step="1" value={ttl} onChange={e=>setTtl(e.target.value)} />
          </div>
          <div className="btn-row" style={{alignSelf:'flex-end'}}>
            <button className="primary" onClick={ban}>Ban IP</button>
            <button onClick={()=>unban()}>Unban IP</button>
          </div>
        </div>

        <div className="sep"></div>

        <div style={{overflowX:'auto'}}>
          <table className="table">
            <thead><tr><th>IP</th><th>TTL (s)</th><th>Actions</th></tr></thead>
            <tbody>
              {rows?.length? rows.map((r,i)=>(
                <tr key={i}>
                  <td style={{fontFamily:'ui-monospace, Menlo, Consolas, monospace'}}>{r.ip}</td>
                  <td>{r.ttlSeconds}</td>
                  <td><button onClick={()=>unban(r.ip)}>Unban</button></td>
                </tr>
              )): <tr><td colSpan="3" className="small">No bans on this page.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
