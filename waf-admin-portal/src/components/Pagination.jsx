import React from 'react'

export default function Pagination({ cursor, onPrev, onNext, disablePrev, disableNext }){
  return (
    <div className="pager">
      <button disabled={disablePrev} onClick={onPrev}>◀ Prev</button>
      <div className="badge">cursor: {cursor}</div>
      <button disabled={disableNext} onClick={onNext}>Next ▶</button>
    </div>
  )
}
