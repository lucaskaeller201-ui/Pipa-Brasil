from duel import *
import duel
class Fixed:
    """Linha presa entre dois postes (pontas imóveis)."""
    def __init__(self,a,b,n=24):
        self.line=sim2.Chain(a,b,n,0.0003*length(sub(b,a)),1/600.0,0.0006,1.1,"line")
        self.line.w[0]=0.0; self.line.w[-1]=0.0; self.line.bins={}
        self.tail=None; self.cut=False; self.t=0.0
    def chains(self): return [self.line]
def fx_part1(F,h):
    c=F.line; f=c.ext_forces(Wind(5.0),0.0)
    for i in range(c.n):
        c.pp[i]=c.p[i]
        if c.w[i]==0: continue
        c.v[i]=add(c.v[i],mul(f[i],h*c.w[i])); c.p[i]=add(c.p[i],mul(c.v[i],h))
    for i in range(c.n-1):
        at=c.cpm*c.rest_seg[i]/(h*h)
        a,b,dl=solve_distance(c.p[i],c.w[i],c.p[i+1],c.w[i+1],c.rest_seg[i],at); c.p[i]=a; c.p[i+1]=b
def fx_part2(F,h):
    c=F.line
    for i in range(c.n): c.v[i]=mul(sub(c.p[i],c.pp[i]),1/h)
_p1=duel.part1; _p2=duel.part2
duel.part1=lambda w,h: fx_part1(w,h) if isinstance(w,Fixed) else _p1(w,h)
duel.part2=lambda w,h: fx_part2(w,h) if isinstance(w,Fixed) else _p2(w,h)
_brk=None
def run(mode=None, secs=10, y=9.5, z=-10.0, strengthA=1e9, strengthF=1e9, pilot=True):
    A=World(Wind(5.0), KiteDef(), line_len=30, segs=24, tail=True, substeps=4)
    pre=1.0-3.0/600.0
    A.line.rest/=pre; A.line.target=A.line.rest; A.line.rest_seg=[r/pre for r in A.line.rest_seg]
    for c in [A.line,A.tail]: c.wear=[0.0]*(c.n-1); c.bins={}
    A.cut=False
    if pilot: A.pilot=Pilot()
    F=Fixed((-15,y,z),(15,y,z))
    STATS['contacts']=0; t_break=None; who=None
    for k in range(round(secs/DT)):
        A.inp={'dar':True} if mode=='dar' else ({'puxar':1.0} if mode=='puxar' else {})
        duel.step([A,F],DT,1.0,strength=1e18)
        wa,_=worst(A.line); wf,_=worst(F.line)
        if t_break is None and (wa>=strengthA or wf>=strengthF):
            t_break=k*DT; who='A' if wa>=strengthA else 'fixa'
    wa,_=worst(A.line); wf,_=worst(F.line)
    md=min_dist(A.line,F.line)
    return dict(contato=round(STATS['contacts']*DT/4,2), elev=round(A.elevation(),1), dist=round(md,3), wA=round(wa,3), wF=round(wf,3), t_break=t_break, who=who, linha=round(sum(A.line.rest_seg),1))
print("parado  ", run())
print("dar     ", run('dar', secs=6, strengthA=1.0, strengthF=1.0))
print("puxar   ", run('puxar', secs=6))
A=World(Wind(5.0), KiteDef(), line_len=30, segs=24, tail=True, substeps=4)
