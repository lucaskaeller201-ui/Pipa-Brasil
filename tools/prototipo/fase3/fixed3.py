from fixed import *
Fixed.fixed=True
A=World(Wind(5.0), KiteDef(), line_len=30, segs=24, tail=True, substeps=4)
pre=1.0-3.0/600.0
A.line.rest/=pre; A.line.target=A.line.rest; A.line.rest_seg=[r/pre for r in A.line.rest_seg]
for c in [A.line,A.tail]: c.wear=[0.0]*(c.n-1); c.bins={}
A.cut=False; A.pilot=Pilot(); A.strength=0.012
F=Fixed((-15,9.5,-10.0),(15,9.5,-10.0))
ev=[]
for k in range(round(15/DT)):
    A.inp={}; duel.step([A,F],DT,1.0,strength=1e18,events=ev)
    if ev: break
print("ruptura", ev, "linha mão %.1f + pedaço %.1f"%(sum(A.line.rest_seg), sum(A.trailing.rest_seg)) if A.cut else "")
y0=A.kite.x[1]; z0=A.kite.x[2]
for k in range(round(8/DT)):
    duel.step([A,F],DT,1.0,strength=1e18,events=ev)
    if k%240==0: print("  avoada y %.1f z %.1f vel %.1f dist à fixa %.2f"%(A.kite.x[1],A.kite.x[2],length(A.kite.v),min_dist(A.trailing,F.line)))
print("avoada y %.1f→%.1f z %.1f→%.1f"%(y0,A.kite.x[1],z0,A.kite.x[2]))
