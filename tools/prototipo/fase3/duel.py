# Duelo de duas pipas no protótipo: duas World do sim2 com contato entre as linhas
# a cada subpasso (mesma ordem do SimWorld em GDScript: restrições internas,
# contato, chão, velocidades).
import math, sys, time
import sim2
from sim2 import *
import contact
from contact import solve_pair_contact, closest_params
DT=1/120; R=0.02
# A raia com rabiola do jogo não usa o modelo de giro (só a raia sem rabiola).
sim2.K_BOW=0.0; sim2.SPIN_Q=0.0; sim2.SPIN_L=0.0

_orig_change=sim2.chain_change_length
def change_with_wear(c,dL):
    # mesmo algoritmo do GDScript, mantendo o desgaste por segmento
    c.rest_seg[0]+=dL
    while c.rest_seg[0] > 1.5*c.target:
        a=c.p[0]; b=c.p[1]; r0=c.rest_seg[0]; f=(r0-c.target)/r0
        newp=add(a, mul(sub(b,a), f))
        c.p.insert(1,newp); c.pp.insert(1,newp); c.v.insert(1,c.v[1]); c.w.insert(1,1.0/c.mass_per_particle)
        c.rest_seg[0]=r0-c.target; c.rest_seg.insert(1,c.target); c.wear.insert(1,c.wear[0]); c.n+=1
    while c.rest_seg[0] < 0.3*c.target and c.n>3:
        c.rest_seg[0]+=c.rest_seg[1]; del c.rest_seg[1]
        c.wear[0]=max(c.wear[0],c.wear[1]); del c.wear[1]
        del c.p[1]; del c.pp[1]; del c.v[1]; del c.w[1]; c.n-=1
    if c.rest_seg[0] < 0.05: c.rest_seg[0]=0.05
sim2.chain_change_length=change_with_wear

def make(offset, az, pilot, L=30.0, tail=True):
    w=World(Wind(5.0), KiteDef(), line_len=L, segs=24, tail=tail, substeps=4, azim_deg=az)
    # sem pré-tensão (igual ao add_flyer do jogo com pre_tension = 0)
    pre=1.0-3.0/600.0
    w.line.rest/=pre; w.line.target=w.line.rest; w.line.rest_seg=[r/pre for r in w.line.rest_seg]
    k=w.kite
    k.x=add(k.x,offset); k.xp=k.x
    for c in [w.line]+([w.tail] if w.tail else []):
        c.p=[add(p,offset) for p in c.p]; c.pp=list(c.p); c.wear=[0.0]*(c.n-1)
    w.hand=add(w.hand,offset)
    if pilot:
        assert offset==(0,0,0)
        w.pilot=Pilot()
    w.cut=False
    return w

def part1(self,h):
    k=self.kite; t=self.t
    if self.pilot and not self.cut:
        self.pilot.update(h, t, self.inp, norm(sub(self.kite.world_point(self.kite.d.tow), Pilot.SHOULDER)), self.tension, self.line)
        self.hand=self.pilot.hand
    F,T=k.aero(self.wind,t)
    F=add(F, mul(G,k.d.mass))
    k.v=add(k.v, mul(F,h/k.d.mass))
    Iw=k.inertia_world(k.w)
    k.w=add(k.w, mul(k.inv_inertia_world(sub(T, cross(k.w,Iw))),h))
    k.xp=k.x; k.qp=k.q
    k.x=add(k.x,mul(k.v,h))
    dq=qmul((0.0,k.w[0],k.w[1],k.w[2]),k.q)
    k.q=qnorm(tuple(k.q[i]+0.5*h*dq[i] for i in range(4)))
    for c in self.chains():
        f=c.ext_forces(self.wind,t)
        for i in range(c.n):
            c.pp[i]=c.p[i]
            if c.w[i]==0: continue
            c.v[i]=add(c.v[i], mul(f[i],h*c.w[i]))
            c.p[i]=add(c.p[i], mul(c.v[i],h))
    L=self.line
    L.p[0]=self.hand
    for i in range(L.n-1):
        at=L.cpm*L.rest_seg[i]/(h*h)
        a,b,dl=solve_distance(L.p[i],L.w[i],L.p[i+1],L.w[i+1],L.rest_seg[i],at)
        L.p[i]=a; L.p[i+1]=b
    lim=0.0
    for i in range(1,L.n):
        lim+=L.rest_seg[i-1]
        d=sub(L.p[i],self.hand); dist=length(d)
        if dist>lim: L.p[i]=add(self.hand, mul(d,lim/dist))
    if not self.cut:
        self.attach(L, L.n-1, k.d.tow, 0.0, 0.0); self.tension=abs(self.last_attach_dl)/(h*h)
    else:
        Tr=self.trailing
        for i in range(Tr.n-1):
            at=Tr.cpm*Tr.rest_seg[i]/(h*h)
            a,b,dl=solve_distance(Tr.p[i],Tr.w[i],Tr.p[i+1],Tr.w[i+1],Tr.rest_seg[i],at)
            Tr.p[i]=a; Tr.p[i+1]=b
        self.attach(Tr, Tr.n-1, k.d.tow, 0.0, 0.0); self.tension=abs(self.last_attach_dl)/(h*h)
    if self.tail:
        Tl=self.tail; att=Tl.alpha/(h*h)
        self.attach(Tl, 0, k.d.tail_attach, 0.0, 0.0)
        for i in range(Tl.n-1):
            a,b,_=solve_distance(Tl.p[i],Tl.w[i],Tl.p[i+1],Tl.w[i+1],Tl.rest,att)
            Tl.p[i]=a; Tl.p[i+1]=b

def part2(self,h):
    k=self.kite
    for c in self.chains():
        for i in range(c.n):
            if c.p[i][1]<0: c.p[i]=(c.pp[i][0]*0.5+c.p[i][0]*0.5, 0.0, c.pp[i][2]*0.5+c.p[i][2]*0.5)
    for cl in k.d.corners:
        wp=k.world_point(cl)
        if wp[1]<0: self.rigid_correct(k, cl, (0,1,0), -wp[1])
    for c in self.chains():
        for i in range(c.n): c.v[i]=mul(sub(c.p[i],c.pp[i]),1/h)
    k.v=mul(sub(k.x,k.xp),1/h)
    dq=qmul(k.q,qconj(k.qp))
    k.w=mul((dq[1],dq[2],dq[3]), 2/h if dq[0]>=0 else -2/h)

def chains(self):
    out=[self.line]
    if self.cut: out.append(self.trailing)
    if self.tail: out.append(self.tail)
    return out
World.chains=chains

def split(c, seg):
    # c fica com 0..seg; devolve seg+1..fim
    r=sim2.Chain((0,0,0),(1,0,0),1,1.0,c.cpm,c.d,c.cd,c.kind)
    r.p=c.p[seg+1:]; r.pp=c.pp[seg+1:]; r.v=c.v[seg+1:]; r.w=c.w[seg+1:]
    r.rest_seg=c.rest_seg[seg+1:]; r.wear=c.wear[seg+1:]; r.n=len(r.p); r.cpm=c.cpm; r.target=c.target; r.mass_per_particle=c.mass_per_particle
    if r.w[0]==0: r.w[0]=1/c.mass_per_particle
    c.p=c.p[:seg+1]; c.pp=c.pp[:seg+1]; c.v=c.v[:seg+1]; c.w=c.w[:seg+1]
    c.rest_seg=c.rest_seg[:seg]; c.wear=c.wear[:seg]; c.n=len(c.p)
    return r

STATS={'contacts':0,'fmax':0.0}
def step(worlds, dt, wear_k, strength=1.0, events=None):
    h=dt/4
    for s in range(4):
        for w in worlds: part1(w,h)
        cs=[]; g=[]
        for gi,w in enumerate(worlds):
            for c in w.chains(): cs.append(c); g.append(gi)
        nc=0
        for it in range(2):
            for a in range(len(cs)):
                for b in range(a+1,len(cs)):
                    if g[a]==g[b]: continue
                    A=cs[a]; B=cs[b]
                    for i in range(A.n-1):
                        for j in range(B.n-1):
                            # pré-filtro barato
                            if abs(A.p[i][0]-B.p[j][0])>3 or abs(A.p[i][1]-B.p[j][1])>3 or abs(A.p[i][2]-B.p[j][2])>3: continue
                            ok,dl=solve_pair_binned(A,i,B,j,h,wear_k if it==0 else 0.0)
                            if ok and it==0:
                                nc+=1; STATS['fmax']=max(STATS['fmax'],dl/(h*h))
        if nc: STATS['contacts']+=1
        for w in worlds: part2(w,h)
        for w in worlds: w.t+=h
        for gi,w in enumerate(worlds):
            if w.cut: continue
            L=w.line
            val,b=worst(L)
            if val>=strength:
                # segmento que contém a faixa
                m=(b+0.5)*BIN; acc=0.0; seg=L.n-2
                for i in range(L.n-2,-1,-1):
                    acc+=L.rest_seg[i]
                    if acc>=m: seg=i; break
                w.trailing=split(L,seg); w.cut=True; w.tension=0.0
                if events is not None: events.append((round(w.t,2),gi,seg))

def min_dist(A,B):
    m=1e9
    for i in range(A.n-1):
        for j in range(B.n-1):
            s,t=closest_params(A.p[i],A.p[i+1],B.p[j],B.p[j+1])
            m=min(m,length(sub(add(A.p[i],mul(sub(A.p[i+1],A.p[i]),s)),add(B.p[j],mul(sub(B.p[j+1],B.p[j]),t)))))
    return m

# ---------- desgaste por ponto do material (faixas de 5 cm) ----------
BIN=0.05
def material_coord(c, i, s):
    # distância ao longo da linha a partir da ponta de fora (lado da pipa):
    # coordenada fixa no material, mesmo quando a carretilha solta linha
    rs=getattr(c,'rest_seg',None) or [c.rest]*(c.n-1)
    return sum(rs[i+1:]) + (1.0-s)*rs[i]
def deposit(c, i, s, amount):
    if not hasattr(c,'bins'): c.bins={}
    b=int(material_coord(c,i,s)/BIN)
    c.bins[b]=c.bins.get(b,0.0)+amount
def worst(c):
    if not getattr(c,'bins',None): return 0.0, None
    b=max(c.bins, key=c.bins.get); return c.bins[b], b
def solve_pair_binned(A,i,B,j,h,wear_k):
    ok,dl=solve_pair_contact(A,i,B,j,R,h,0.0)
    if not ok or wear_k<=0: return ok,dl
    s,t=closest_params(A.p[i],A.p[i+1],B.p[j],B.p[j+1])
    n=norm(sub(add(A.p[i],mul(sub(A.p[i+1],A.p[i]),s)), add(B.p[j],mul(sub(B.p[j+1],B.p[j]),t))))
    va=add(mul(A.v[i],1-s),mul(A.v[i+1],s)); vb=add(mul(B.v[j],1-t),mul(B.v[j+1],t))
    vrel=sub(va,vb); slide=length(sub(vrel,mul(n,dot(vrel,n))))
    W=wear_k*(dl/(h*h))*slide*h
    deposit(A,i,s,W); deposit(B,j,t,W)
    return ok,dl
contact_fn=solve_pair_binned
