import React from 'react'
import { api, getConfig } from '../api'

export default function HealthBadge(){
  const [ok,setOk] = React.useState(null)
  const [err,setErr] = React.useState(null)

  async function ping(){
    try{
      const data = await api.health(getConfig())
      setOk(true); setErr(null)
    }catch(e){
      setOk(false); setErr(e.message)
    }
  }
  React.useEffect(()=>{ ping() },[])

  return (
    <div className="status">
      <div className={'dot ' + (ok ? 'ok' : (ok===false?'err':''))}></div>
      <span className="small">{ok===null?'Checking /admin/health...': ok?'Healthy':'Error: '+err}</span>
      <button className="ghost" onClick={ping} title="Refresh">↻</button>
    </div>
  )
}
