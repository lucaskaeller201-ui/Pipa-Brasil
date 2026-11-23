from duel import *
A=make((0,0,0),18,True); B=make((8,0,0),-18,False)
ev=[]
for k in range(round(6/DT)):
    A.inp={'dar':True} if not A.cut else {}
    step([A,B],DT,1.0,strength=1.0,events=ev)
    if ev: break
print("ruptura:",ev, "A cortada" if A.cut else "", "B cortada" if B.cut else "")
cut=A if A.cut else B; other=B if A.cut else A
y0=cut.kite.x[1]; z0=cut.kite.x[2]
print("linha da mão %.1f m, pedaço com a pipa %.1f m"%(sum(cut.line.rest_seg), sum(cut.trailing.rest_seg)))
for k in range(round(8/DT)):
    step([A,B],DT,1.0,strength=1.0,events=ev)
    if k%240==0: print("  t%.1f avoada y %.1f z %.1f vel %.1f | outra elev %.1f"%(A.t,cut.kite.x[1],cut.kite.x[2],length(cut.kite.v),other.elevation()))
print("avoada: y %.1f→%.1f z %.1f→%.1f"%(y0,cut.kite.x[1],z0,cut.kite.x[2]))
