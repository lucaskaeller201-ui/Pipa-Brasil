from duel import *
import itertools
def setup(elA,elB,az,dz,LA,LB):
    A=make((0,0,0),az,True,L=LA); B=make((8,0,0),-az,False,L=LB)
    # perturbação: começa a linha de A deslocada dz no eixo z (como no jogo)
    A.hand=add(A.hand,(0,0,dz)); A.line.p[0]=A.hand; A.line.pp[0]=A.hand
    return A,B
def contact_time(elA,elB,az,dz,LA,LB,secs=6):
    # elevação inicial diferente: recria com azimute/elevação próprios
    A=World(Wind(5.0), KiteDef(), line_len=LA, segs=24, tail=True, substeps=4, elev_deg=elA, azim_deg=az)
    B=World(Wind(5.0), KiteDef(), line_len=LB, segs=24, tail=True, substeps=4, elev_deg=elB, azim_deg=-az)
    for w,off,pil in ((A,(0,0,0),True),(B,(8,0,0),False)):
        pre=1.0-3.0/600.0
        w.line.rest/=pre; w.line.target=w.line.rest; w.line.rest_seg=[r/pre for r in w.line.rest_seg]
        k=w.kite; k.x=add(k.x,off); k.xp=k.x
        for c in [w.line,w.tail]:
            c.p=[add(p,off) for p in c.p]; c.pp=list(c.p); c.wear=[0.0]*(c.n-1); c.bins={}
        w.hand=add(w.hand,off); w.cut=False
        if pil: w.pilot=Pilot()
    A.hand=add(A.hand,(0,0,dz)); A.line.p[0]=A.hand
    STATS['contacts']=0
    for k in range(round(secs/DT)): step([A,B],DT,0.0)
    return STATS['contacts']*DT/4
res=[]
for elA,elB,az,LA,LB in itertools.product((30,40),(25,30),(18,25),(30,),(25,30)):
    ts=[contact_time(elA,elB,az,dz,LA,LB) for dz in (0.0,-0.35,0.3)]
    res.append((min(ts),elA,elB,az,LA,LB,[round(t,2) for t in ts]))
    print("elevA %d elevB %d az %d LA %d LB %d: contato %s"%(elA,elB,az,LA,LB,[round(t,2) for t in ts]), flush=True)
res.sort(reverse=True); print("melhor", res[:3])
