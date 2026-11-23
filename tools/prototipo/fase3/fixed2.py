from fixed import *
def run2(mode, secs_hook=6.0, secs=4.0):
    A=World(Wind(5.0), KiteDef(), line_len=30, segs=24, tail=True, substeps=4)
    pre=1.0-3.0/600.0
    A.line.rest/=pre; A.line.target=A.line.rest; A.line.rest_seg=[r/pre for r in A.line.rest_seg]
    for c in [A.line,A.tail]: c.wear=[0.0]*(c.n-1); c.bins={}
    A.cut=False; A.pilot=Pilot()
    F=Fixed((-15,9.5,-10.0),(15,9.5,-10.0))
    for k in range(round(secs_hook/DT)): A.inp={}; duel.step([A,F],DT,1.0,strength=1e18)
    w0=(worst(A.line)[0], worst(F.line)[0]); STATS['contacts']=0
    for k in range(round(secs/DT)):
        A.inp={'recolher':True} if mode=='recolher' else ({'dar':True} if mode=='dar' else ({'puxar':1.0} if mode=='puxar' else {}))
        duel.step([A,F],DT,1.0,strength=1e18)
    wa,_=worst(A.line); wf,_=worst(F.line)
    return dict(desgaste_antes=tuple(round(x,3) for x in w0), contato=round(STATS['contacts']*DT/4,2), wA=round(wa,3), wF=round(wf,3), elev=round(A.elevation(),1), dist=round(min_dist(A.line,F.line),3), linha=round(sum(A.line.rest_seg),1))
for m in ('parado','recolher','dar','puxar'):
    print("%-8s"%m, run2(m), flush=True)
