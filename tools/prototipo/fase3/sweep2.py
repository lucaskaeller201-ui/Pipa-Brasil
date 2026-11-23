from duel import *
import itertools
def contact_time(az,LA,LB,dA,secs=6,mode=None,wear=0.0,strength=1e9):
    A=World(Wind(5.0), KiteDef(), line_len=LA, segs=24, tail=True, substeps=4, elev_deg=30, azim_deg=az)
    B=World(Wind(5.0), KiteDef(), line_len=LB, segs=24, tail=True, substeps=4, elev_deg=30, azim_deg=-az)
    for w,off,pil in ((A,dA,True),(B,(8,0,0),False)):
        pre=1.0-3.0/600.0
        w.line.rest/=pre; w.line.target=w.line.rest; w.line.rest_seg=[r/pre for r in w.line.rest_seg]
        k=w.kite; k.x=add(k.x,off); k.xp=k.x
        for c in [w.line,w.tail]:
            c.p=[add(p,off) for p in c.p]; c.pp=list(c.p); c.wear=[0.0]*(c.n-1); c.bins={}
        w.hand=add(w.hand,off); w.cut=False
        if pil: w.pilot=Pilot()
    STATS['contacts']=0; ev=[]
    for k in range(round(secs/DT)):
        A.inp={'dar':True} if mode=='dar' and not A.cut else {}
        step([A,B],DT,wear,strength=strength,events=ev)
        if ev and mode=='dar': break
    return STATS['contacts']*DT/4, ev
if __name__=="__main__":
    offs=[(0,0,0),(0,0,-0.35),(0,0,0.3),(0,0.2,-0.35),(0,-0.2,0)]
    for az,LA,LB in ((18,30,30),(18,30,25),(25,30,25),(25,30,20),(18,30,20)):
        ts=[round(contact_time(az,LA,LB,o)[0],2) for o in offs]
        print("az %d LA %d LB %d: contato %s"%(az,LA,LB,ts), flush=True)
