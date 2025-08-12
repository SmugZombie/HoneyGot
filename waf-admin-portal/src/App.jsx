import React from 'react'
import TopBar from './components/TopBar'
import HealthBadge from './components/HealthBadge'
import Canaries from './components/Canaries'
import Bans from './components/Bans'

export default function App(){
  const [, setTick] = React.useState(0)
  return (
    <div className="container">
      <div className="topbar" style={{marginTop:'1rem'}}>
        <h1 style={{margin:0,fontSize:'1.25rem'}}>WAF Admin Portal</h1>
        <HealthBadge/>
      </div>
      <TopBar onConfig={()=>setTick(t=>t+1)} />
      <div className="row" style={{marginTop:'1rem', alignItems:'stretch'}}>
        <div style={{flex:1, minWidth:400}}><Canaries /></div>
        <div style={{flex:1, minWidth:400}}><Bans /></div>
      </div>
      <p className="small" style={{marginTop:'1rem'}}>Tip: ensure CORS is enabled on the WAF <code>/admin</code> endpoints (see README).</p>
    </div>
  )
}
