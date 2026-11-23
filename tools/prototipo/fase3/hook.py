from duel import *
def mkw(off, az, el, L, pil):
    w=World(Wind(5.0), KiteDef(), line_len=L, segs=24, tail=True, substeps=4, elev_deg=el, azim_deg=az)
    pre=1.0-3.0/600.0
    w.line.rest/=pre; w.line.target=w.line.rest; w.line.rest_seg=[r/pre for r in w.line.rest_seg]
    k=w.kite; k.x=add(k.x,off); k.xp=k.x
    for c in [w.line,w.tail]:
        c.p=[add(p,off) for p in c.p]; c.pp=list(c.p); c.wear=[0.0]*(c.n-1); c.bins={}
    w.hand=add(w.hand,off); w.cut=False
    if pil: w.pilot=Pilot()
    return w
def run(dA=(0,0,0), mode=None, secs=8, wear=1.0, strength=1e9, elA=25, azA=40, verbose=False):
    B=mkw((8,0,0),0,30,30,False)
    for k in range(round(15/DT)): step([B],DT,0.0)
    A=mkw(dA,azA,elA,30,True)
    STATS['contacts']=0; ev=[]; first=None; last=None
    for k in range(round(secs/DT)):
        A.inp={'dar':True} if mode=='dar' and not A.cut else {}
        c0=STATS['contacts']
        step([A,B],DT,wear,strength=strength,events=ev)
        if STATS['contacts']>c0:
            if first is None: first=k*DT
            last=k*DT
        if verbose and k%120==0: print("  t%.1f A x %.1f elev %.1f | B x %.1f elev %.1f | contato %.2f s"%(k*DT,A.kite.x[0],A.elevation(),B.kite.x[0],B.elevation(),STATS['contacts']*DT/4))
        if ev and mode=='dar': break
    wa,_=worst(A.line); wb,_=worst(B.line)
    return STATS['contacts']*DT/4, first, last, ev, wa, wb, A, B
if __name__=="__main__":
    t,f,l,ev,wa,wb,A,B=run(verbose=True)
    print("contato %.2f s (de %s a %s)"%(t,f,l))
    for o in ((0,0,-0.35),(0,0.2,0),(0,0,0.3),(0,-0.2,-0.35)):
        r=run(dA=o); print("deslocamento",o,"contato %.2f s, desgaste A %.3f B %.3f"%(r[0],r[4],r[5]),flush=True)
    for m in ('dar',):
        r=run(mode=m,strength=1.0); print(m,"ruptura",r[3],"desgaste A %.2f B %.2f"%(r[4],r[5]))
