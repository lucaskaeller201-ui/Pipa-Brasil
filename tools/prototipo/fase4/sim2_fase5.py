# Protótipo Python da física do PIPA BRASIL (Fase 1).
# Espelha a estrutura que será portada para GDScript em sim/.
import math, random

# ---------------- vetores (tuplas) ----------------
def add(a,b): return (a[0]+b[0],a[1]+b[1],a[2]+b[2])
def sub(a,b): return (a[0]-b[0],a[1]-b[1],a[2]-b[2])
def mul(a,s): return (a[0]*s,a[1]*s,a[2]*s)
def dot(a,b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(dot(a,a))
def norm(a):
    l=length(a); return (0.0,0.0,0.0) if l<1e-12 else mul(a,1.0/l)

# quaternions (w,x,y,z)
def qmul(a,b):
    aw,ax,ay,az=a; bw,bx,by,bz=b
    return (aw*bw-ax*bx-ay*by-az*bz, aw*bx+ax*bw+ay*bz-az*by, aw*by-ax*bz+ay*bw+az*bx, aw*bz+ax*by-ay*bx+az*bw)
def qnorm(q):
    l=math.sqrt(sum(c*c for c in q)); return tuple(c/l for c in q)
def qconj(q): return (q[0],-q[1],-q[2],-q[3])
def qrot(q,v):
    p=qmul(qmul(q,(0.0,v[0],v[1],v[2])),qconj(q)); return (p[1],p[2],p[3])
def qinvrot(q,v): return qrot(qconj(q),v)
def q_from_axis_angle(axis,ang):
    s=math.sin(ang/2); a=norm(axis); return (math.cos(ang/2),a[0]*s,a[1]*s,a[2]*s)

RHO=1.2
G=(0.0,-9.81,0.0)

# ---------------- vento ----------------
class Wind:
    def __init__(self, speed=5.0, direction=(0,0,-1), turbulence=0.0, seed=1):
        self.speed=speed; self.dir=norm(direction); self.turb=turbulence
        rng=random.Random(seed)
        self.modes=[]
        for k in range(3):
            w=rng.uniform(0.15,0.9)
            self.modes.append(((rng.uniform(-1,1),rng.uniform(-0.3,0.3),rng.uniform(-1,1)), w, rng.uniform(0,6.283), (rng.uniform(-.05,.05),rng.uniform(-.05,.05),rng.uniform(-.05,.05))))
        self.gust_t0=None; self.gust_speed=0.0
    def base_speed(self,t):
        if self.gust_t0 is not None and t>=self.gust_t0 and t<self.gust_t0+getattr(self,'gust_dur',1e9): return self.gust_speed
        return self.speed
    def sample(self,p,t):
        h=max(p[1],0.5)
        s=self.base_speed(t)*(h/10.0)**0.14
        v=mul(self.dir,s)
        if self.turb>0:
            d=(0.0,0.0,0.0)
            for amp_dir,w,ph,kv in self.modes:
                d=add(d, mul(amp_dir, math.sin(w*t+ph+dot(kv,p))))
            v=add(v, mul(d, self.turb*s/1.7))
        return v

# ---------------- aerodinâmica de placa plana ----------------
A_LIFT=2.2; CN90=1.2; CF=0.02
SPIN_Q=1.0; SPIN_L=0.3; K_BOW=0.5; BOW_MODE='wind'; K_TAUT=0.0; DESB=None; AXIS=False; YAW_TAUT=0.0; K_SIDE=0.0; SPIN_MAX=0.0; GIVE_FRIC=0.3; GIVE_TENSION=False; LONG=[]; LAT=[]
def cn(sin_a):
    s=abs(sin_a); c=math.sqrt(max(0.0,1-s*s))
    return A_LIFT*s*c + CN90*s*s

# ---------------- definição da raia ----------------
class KiteDef:
    def __init__(self, tow=(0.0,0.12,0.28), dihedral_deg=12.0):
        # coordenadas locais com origem no centro de massa. Y = bico, Z = frente (lado do cabresto)
        top=(0.0,0.25,0.0); bot=(0.0,-0.35,0.0); dh=math.radians(dihedral_deg)
        L=(-0.25*math.cos(dh),0.05,-0.25*math.sin(dh)); R=(0.25*math.cos(dh),0.05,-0.25*math.sin(dh)); C=(0.0,0.05,0.0)
        self.tris=[(C,top,L),(C,R,top),(C,L,bot),(C,bot,R)]
        self.corners=[top,bot,L,R]
        self.mass=0.025
        a=0.6; b=0.5
        self.I=(self.mass*a*a/24, self.mass*b*b/24, self.mass*(a*a+b*b)/24)
        self.c_ref=0.6
        self.tow=tow
        self.tail_attach=bot
        self.flex=None
        self.panels=[]
        for t in self.tris:
            e1=sub(t[1],t[0]); e2=sub(t[2],t[0]); cr=cross(e1,e2); area=0.5*length(cr)
            cen=mul(add(add(t[0],t[1]),t[2]),1/3); n=norm(cr)
            if n[2]<0: n=mul(n,-1)
            self.panels.append((cen,n,area))

def kd_enable_flex(kd, d_min=2.0, d_max=16.0, t_ref=1.2):
    kd.flex=(math.radians(d_min), math.radians(d_max), t_ref); kd.delta=math.radians(d_max)
    # painéis planos: lados esquerdo (x<0) e direito
    kd.flat=[]
    for cen,n,area in kd.panels:
        side=-1 if cen[0]<0 else 1
        kd.flat.append((cen,side,area))
def kd_update_flex(kd, tension, h):
    if not kd.flex: return
    dmin,dmax,tref=kd.flex
    goal=dmin+(dmax-dmin)*min(1.0,tension/tref)
    tau=0.03 if goal>kd.delta else 0.4   # enverga rápido, relaxa mais devagar
    kd.delta+= (goal-kd.delta)*min(1.0,h/tau)
    sd=math.sin(kd.delta); cd=math.cos(kd.delta)
    kd.panels=[(cen,(side*sd,0.0,cd),area) for cen,side,area in kd.flat]
KiteDef.update_flex=lambda self,t,h: kd_update_flex(self,t,h)

class Kite:
    def __init__(self, d, pos, q=(1,0,0,0)):
        self.d=d; self.x=pos; self.q=q; self.v=(0.0,0.0,0.0); self.w=(0.0,0.0,0.0)
        self.xp=pos; self.qp=q
        self.last_force=(0,0,0); self.last_aoa=0.0
    def world_point(self,lp): return add(self.x, qrot(self.q,lp))
    def inv_inertia_world(self,v):
        # I_w^-1 v = R I^-1 R^T v
        l=qinvrot(self.q,v); I=self.d.I
        return qrot(self.q,(l[0]/I[0],l[1]/I[1],l[2]/I[2]))
    def inertia_world(self,v):
        l=qinvrot(self.q,v); I=self.d.I
        return qrot(self.q,(l[0]*I[0],l[1]*I[1],l[2]*I[2]))
    def point_velocity(self,wp): return add(self.v, cross(self.w, sub(wp,self.x)))
    def aero(self, wind, t):
        F=(0.0,0.0,0.0); T=(0.0,0.0,0.0); aoa_acc=0.0; area_acc=0.0
        for cen,nl,area in self.d.panels:
            r=qrot(self.q,cen); p=add(self.x,r); n=qrot(self.q,nl)
            va=sub(wind.sample(p,t), add(self.v,cross(self.w,r)))
            V=length(va)
            if V<1e-6: continue
            vn=dot(va,n); sin_a=vn/V
            qd=0.5*RHO*V*V
            Fn=mul(n, qd*area*cn(sin_a)*(1 if vn>=0 else -1))
            vt=sub(va,mul(n,vn)); vtl=length(vt)
            Ft=mul(vt, qd*area*CF/vtl) if vtl>1e-6 else (0,0,0)
            # centro de pressão: avança para o lado de onde vem o fluxo no plano
            shift=(0,0,0)
            if vtl>1e-6:
                shift=mul(vt, -(0.25*self.d.c_ref*(1-abs(sin_a)))/vtl)
            rp=add(r,shift)
            f=add(Fn,Ft); F=add(F,f); T=add(T,cross(rp,f))
            aoa_acc+=math.degrees(math.asin(min(1,abs(sin_a))))*area; area_acc+=area
        self.last_aoa=aoa_acc/area_acc if area_acc>0 else 0
        # --- momentos em torno da normal (giro no plano da pipa) ---
        d=self.d; n=qrot(self.q,(0,0,1)); A=sum(p[2] for p in d.panels)
        va=sub(wind.sample(self.x,t), self.v); V=length(va)
        wn=dot(self.w,n)
        R=d.c_ref*0.5
        # amortecimento por arrasto das bordas e varetas
        bt=1.0
        if d.flex:
            dmin_,dmax_,_=d.flex; bt=max(0.0,min(1.0,(d.delta-dmin_)/(dmax_-dmin_)))
        damp=-(SPIN_Q*0.5*RHO*A*R**3*abs(wn)*wn + (SPIN_L+K_TAUT*bt)*0.5*RHO*max(V,1.0)*A*R*R*wn)
        T=add(T, mul(n,damp))
        # estabilidade direcional da vareta envergada: alinha a espinha com o fluxo no plano
        vb=va if BOW_MODE=='wind' else mul(self.v,-1.0)   # 'motion': só o movimento da pipa
        Vb=length(vb)
        if Vb>0.5:
            V=Vb; va=vb
            vt=sub(va, mul(n,dot(va,n))); vtl=length(vt)
            if vtl>1e-3:
                b=1.0
                if d.flex:
                    dmin,dmax,_=d.flex; b=max(0.0,min(1.0,(d.delta-dmin)/(dmax-dmin)))
                tail_dir=qrot(self.q,(0,-1,0))
                s_th=dot(n, cross(tail_dir, mul(vt,1/vtl)))
                if AXIS:
                    c_th=dot(tail_dir, mul(vt,1/vtl))
                    s_th=-s_th*c_th
                tau=K_BOW*b*0.5*RHO*V*V*A*d.c_ref*s_th*(vtl/V)
                T=add(T, mul(n,tau))
        # tendência de giro quando a vareta relaxa (linha frouxa): momento
        # empírico com o sentido preferido de cada pipa
        if d.flex and getattr(d,'spin_bias',0.0)!=0.0:
            dmin,dmax,_=d.flex; b=max(0.0,min(1.0,(d.delta-dmin)/(dmax-dmin)))
            Vw=length(wind.sample(self.x,t))
            T=add(T, mul(n, d.spin_bias*(1-b)**2*0.5*RHO*Vw*Vw*A*d.c_ref))
        if K_SIDE>0:
            X=qrot(self.q,(1,0,0)); vas=sub(wind.sample(self.x,t), self.v); vx=dot(vas,X)
            F=add(F, mul(X, K_SIDE*0.5*RHO*A*abs(vx)*vx))
        return F,T

# ---------------- cadeia de partículas (linha / rabiola) ----------------
class Chain:
    def __init__(self, start, end, n_seg, mass_total, compliance_per_m, diameter, cd, kind="line"):
        self.n=n_seg+1
        self.p=[add(start, mul(sub(end,start), i/n_seg)) for i in range(self.n)]
        self.pp=list(self.p); self.v=[(0.0,0.0,0.0)]*self.n
        m=mass_total/n_seg
        self.w=[1.0/m]*self.n
        self.rest=length(sub(end,start))/n_seg
        self.target=self.rest
        self.cpm=compliance_per_m
        self.rest_seg=[self.rest]*n_seg
        self.mass_per_particle=mass_total/n_seg
        self.alpha=compliance_per_m*self.rest
        self.d=diameter; self.cd=cd; self.kind=kind
        self.tension0=0.0
    def ext_forces(self, wind, t):
        f=[G if True else None]*self.n
        f=[mul(G,1.0/self.w[i]) if self.w[i]>0 else (0,0,0) for i in range(self.n)]
        for i in range(self.n-1):
            a=self.p[i]; b=self.p[i+1]; seg=sub(b,a); L=length(seg)
            if L<1e-6: continue
            e=mul(seg,1/L); mid=mul(add(a,b),0.5)
            vrel=sub(wind.sample(mid,t), mul(add(self.v[i],self.v[i+1]),0.5))
            if self.kind=="line":
                vn=sub(vrel, mul(e,dot(vrel,e)))  # componente perpendicular
                s=length(vn); fd=mul(vn, 0.5*RHO*self.cd*self.d*L*s)
            else:  # rabiola: arrasto de fita, quase isotrópico
                s=length(vrel); fd=mul(vrel, 0.5*RHO*self.cd*self.d*L*s)
            f[i]=add(f[i],mul(fd,0.5)); f[i+1]=add(f[i+1],mul(fd,0.5))
        return f

def solve_distance(p, w1, q_, w2, rest, alpha_t):
    d=sub(p,q_); L=length(d)
    if L<1e-9: return p,q_,0.0
    n=mul(d,1/L); C=L-rest
    dl=-C/(w1+w2+alpha_t)
    return add(p,mul(n,w1*dl)), sub(q_,mul(n,w2*dl)), dl

def chain_total(c): return sum(c.rest_seg)
def chain_change_length(c, dL):
    # muda o comprimento no segmento da mão (índice 0) e insere/remove nós
    c.rest_seg[0]+=dL
    while c.rest_seg[0] > 1.5*c.target:
        a=c.p[0]; b=c.p[1]; r0=c.rest_seg[0]
        f=(r0-c.target)/r0
        newp=add(a, mul(sub(b,a), f))
        c.p.insert(1,newp); c.pp.insert(1,newp); c.v.insert(1,c.v[1]); c.w.insert(1,1.0/c.mass_per_particle)
        c.rest_seg[0]=r0-c.target; c.rest_seg.insert(1,c.target); c.n+=1
    while c.rest_seg[0] < 0.3*c.target and c.n>3:
        c.rest_seg[0]+=c.rest_seg[1]; del c.rest_seg[1]
        del c.p[1]; del c.pp[1]; del c.v[1]; del c.w[1]; c.n-=1
    if c.rest_seg[0] < 0.05: c.rest_seg[0]=0.05

class Pilot:
    SHOULDER=(0.0,1.45,0.0)
    def __init__(self):
        self.offset=0.0; self.offset_v=0.0   # deslocamento da mão ao longo da linha (+ = para a pipa)
        self.target=0.0
        self.events=[]   # (t_inicio, duração, alvo) movimentos agendados
        self.vmax=4.0
        self.mode='lock'; self.spool_speed=0.0
        self.hand=add(self.SHOULDER,(0.0,-0.25,-0.35))
        self.t=0.0
    def command(self, name, t):
        if name=='puxao': self.events=[(t,0.15,-0.45,4.5),(t+0.15,0.45,0.0,1.5)]
        elif name=='arrancao': self.events=[(t,0.22,-0.7,7.0),(t+0.22,0.6,0.0,1.5)]
        elif name in ('desb_esq','desb_dir'):
            sg=-1 if name=='desb_esq' else 1
            self.events=[(t+e[0],e[1],e[2],e[3]) for e in LONG]
            self.lat_events=[(t+e[0],e[1],sg*e[2],e[3]) for e in LAT]
        elif name=='desbicar' and DESB: self.events=[(t+e[0],e[1],e[2],e[3]) for e in DESB]
        elif name=='desbicar': self.events=[(t,0.12,0.40,5.0),(t+0.12,0.18,0.40,5.0),(t+0.30,0.15,-0.40,5.0),(t+0.45,0.4,0.0,1.5)]
    def update(self, h, t, inp, dir_kite, tension, line):
        # inp: dict com 'puxar','afrouxar' (0..1), 'dar','recolher','largar' (bool)
        tgt=0.0; vmax=2.0
        if self.events:
            act=[e for e in self.events if e[0]<=t]
            if act:
                e=act[-1]; tgt=e[2]; vmax=e[3]
            self.events=[e for e in self.events if e[0]+e[1]>t]
        tgt+= -0.5*inp.get('puxar',0.0) + 0.45*inp.get('afrouxar',0.0)
        # mola criticamente amortecida com velocidade máxima
        w=30.0
        acc=w*w*(tgt-self.offset)-2*w*self.offset_v
        self.offset_v+=acc*h
        self.offset_v=max(-vmax,min(vmax,self.offset_v))
        self.offset+=self.offset_v*h
        base=add(self.SHOULDER,(0.0,-0.25,0.0))
        lt=0.0; lv=3.0
        if getattr(self,'lat_events',None):
            act=[e for e in self.lat_events if e[0]<=t]
            if act: lt=act[-1][2]; lv=act[-1][3]
            self.lat_events=[e for e in self.lat_events if e[0]+e[1]>t]
        if not hasattr(self,'lat'): self.lat=0.0; self.lat_v=0.0
        acc=w*w*(lt-self.lat)-2*w*self.lat_v
        self.lat_v=max(-lv,min(lv,self.lat_v+acc*h)); self.lat+=self.lat_v*h
        side=norm(cross(dir_kite,(0,1,0)))
        self.hand=add(add(base, mul(dir_kite, 0.35+self.offset)), mul(side,self.lat))
        # carretilha
        M_EFF=0.05; FRIC=0.3
        if inp.get('haul',0.0)>0.0 or (inp.get('haul',0.0)<0.0 and not GIVE_TENSION):
            self.spool_speed=0.0; dL=-inp['haul']*h
        elif inp.get('haul',0.0)<0.0 and GIVE_TENSION:
            # dar linha: a linha escorrega pela mão quando a pipa puxa (até o limite do gesto)
            self.spool_speed=max(0.0, min(-inp['haul'], self.spool_speed+(tension-GIVE_FRIC)/0.02*h))
            dL=self.spool_speed*h
        elif inp.get('largar'):
            self.spool_speed=max(0.0, self.spool_speed+(tension-FRIC)/M_EFF*h)
            dL=self.spool_speed*h
        elif inp.get('dar'):
            self.spool_speed=max(0.0, min(2.0, self.spool_speed+(tension-FRIC)/M_EFF*h))
            dL=self.spool_speed*h
        elif inp.get('recolher') and tension<35.0:
            self.spool_speed=0.0; dL=-1.2*h
        else:
            self.spool_speed=0.0; dL=0.0
        if dL!=0.0: chain_change_length(line, dL)

class World:
    def __init__(self, wind, kdef, line_len=30.0, elev_deg=30.0, segs=24, tail=True, hand=(0,1.2,0), substeps=8, ea=600.0, azim_deg=0.0):
        self.wind=wind; self.t=0.0; self.substeps=substeps; self.hand=hand
        e=math.radians(elev_deg)
        az=math.radians(azim_deg)
        dirv=(math.cos(e)*math.sin(az), math.sin(e), -math.cos(e)*math.cos(az))
        bridle=add(hand, mul(dirv,line_len))
        # orienta a pipa: face (+Z local) apontando para a mão
        tow_l=kdef.tow
        self.kite=Kite(kdef, (0,0,0))
        # rotação inicial: inclina a pipa em X para a face olhar para a mão
        self.kite.q=qmul(q_from_axis_angle((0,1,0), -az), q_from_axis_angle((1,0,0), -e))
        self.kite.x=sub(bridle, qrot(self.kite.q,tow_l))
        self.kite.xp=self.kite.x; self.kite.qp=self.kite.q
        self.line=Chain(hand, bridle, segs, 0.0003*line_len, 1.0/ea, 0.0006, 1.1, "line")
        self.line.w[0]=0.0
        # lançamento com a linha já esticada (pré-tensão de cerca de 3 N)
        pre=1.0-3.0/ea
        self.line.rest*=pre; self.line.target=self.line.rest; self.line.rest_seg=[r*pre for r in self.line.rest_seg]
        self.tail=None
        if tail:
            ta=self.kite.world_point(kdef.tail_attach)
            self.tail=Chain(ta, add(ta,(0,-2.0,0.0)), 10, 0.006, 1/200.0, 0.025, 0.6, "tail")
        self.tension=0.0
        self.pilot=None; self.inp={}
    def step(self, dt):
        h=dt/self.substeps
        for _ in range(self.substeps): self.substep(h)
        self.t+=dt
    def substep(self,h):
        k=self.kite; t=self.t
        if self.pilot:
            self.pilot.update(h, t, self.inp, norm(sub(self.kite.world_point(self.kite.d.tow), Pilot.SHOULDER)), self.tension, self.line)
            self.hand=self.pilot.hand
        k.d.update_flex(self.tension, h)
        F,T=k.aero(self.wind,t)
        k.last_force=F
        F=add(F, mul(G,k.d.mass))
        k.v=add(k.v, mul(F,h/k.d.mass))
        Iw=k.inertia_world(k.w)
        k.w=add(k.w, mul(k.inv_inertia_world(sub(T, cross(k.w,Iw))),h))
        if YAW_TAUT>0 and k.d.flex:
            dmin_,dmax_,_=k.d.flex; bt=max(0.0,min(1.0,(k.d.delta-dmin_)/(dmax_-dmin_)))
            nn=qrot(k.q,(0,0,1)); wn_=dot(k.w,nn)
            k.w=sub(k.w, mul(nn, wn_*(1-math.exp(-YAW_TAUT*bt**2*h))))
        if SPIN_MAX>0:
            nn=qrot(k.q,(0,0,1)); wn_=dot(k.w,nn)
            if abs(wn_)>SPIN_MAX: k.w=sub(k.w, mul(nn, wn_-math.copysign(SPIN_MAX,wn_)))
        k.xp=k.x; k.qp=k.q
        k.x=add(k.x,mul(k.v,h))
        dq=qmul((0.0,k.w[0],k.w[1],k.w[2]),k.q)
        k.q=qnorm(tuple(k.q[i]+0.5*h*dq[i] for i in range(4)))
        chains=[self.line]+([self.tail] if self.tail else [])
        for c in chains:
            f=c.ext_forces(self.wind,t)
            for i in range(c.n):
                c.pp[i]=c.p[i]
                if c.w[i]==0: continue
                c.v[i]=add(c.v[i], mul(f[i],h*c.w[i]))
                c.p[i]=add(c.p[i], mul(c.v[i],h))
        self.line.p[0]=self.hand
        # restrições da linha
        L=self.line
        for i in range(L.n-1):
            at=L.cpm*L.rest_seg[i]/(h*h)
            a,b,dl=solve_distance(L.p[i],L.w[i],L.p[i+1],L.w[i+1],L.rest_seg[i],at)
            L.p[i]=a; L.p[i+1]=b
        lim=0.0
        for i in range(1,L.n):
            lim+=L.rest_seg[i-1]
            d=sub(L.p[i],self.hand); dist=length(d)
            if dist>lim: L.p[i]=add(self.hand, mul(d,lim/dist))
        # último nó da linha preso ao cabresto (ponto rígido) por um segmento
        self.attach(L, L.n-1, k.d.tow, 0.0, 0.0)
        self.tension=abs(self.last_attach_dl)/(h*h)
        if self.tail:
            Tl=self.tail; att=Tl.alpha/(h*h)
            self.attach(Tl, 0, k.d.tail_attach, 0.0, 0.0)
            for i in range(Tl.n-1):
                a,b,_=solve_distance(Tl.p[i],Tl.w[i],Tl.p[i+1],Tl.w[i+1],Tl.rest,att)
                Tl.p[i]=a; Tl.p[i+1]=b
        # chão
        for c in chains:
            for i in range(c.n):
                if c.p[i][1]<0:
                    c.p[i]=(c.pp[i][0]*0.5+c.p[i][0]*0.5, 0.0, c.pp[i][2]*0.5+c.p[i][2]*0.5)
        contato=False
        for cl in k.d.corners:
            wp=k.world_point(cl)
            if wp[1]<0:
                self.rigid_correct(k, cl, (0,1,0), -wp[1]); contato=True
        # velocidades
        for c in chains:
            for i in range(c.n):
                c.v[i]=mul(sub(c.p[i],c.pp[i]),1/h)
        k.v=mul(sub(k.x,k.xp),1/h)
        dq=qmul(k.q,qconj(k.qp))
        k.w=mul((dq[1],dq[2],dq[3]), 2/h if dq[0]>=0 else -2/h)
        if contato:  # atrito simples com o chão
            k.v=(k.v[0]*0.9, k.v[1], k.v[2]*0.9); k.w=mul(k.w,0.9)
    def rigid_correct(self, k, lp, n, depth):
        r=qrot(k.q,lp); rn=cross(r,n)
        wgen=1/k.d.mass + dot(rn, k.inv_inertia_world(rn))
        dl=depth/wgen
        P=mul(n,dl)
        k.x=add(k.x, mul(P,1/k.d.mass))
        dth=k.inv_inertia_world(cross(r,P))
        dq=qmul((0.0,dth[0],dth[1],dth[2]),k.q)
        k.q=qnorm(tuple(k.q[i]+0.5*dq[i] for i in range(4)))
    def attach(self, c, idx, lp, rest, alpha_t):
        k=self.kite
        self.last_attach_dl=0.0
        r=qrot(k.q,lp); bp=add(k.x,r)
        d=sub(c.p[idx],bp); L=length(d)
        if L<1e-9: return
        n=mul(d,1/L); C=L-rest
        rn=cross(r,n)
        wb=1/k.d.mass + dot(rn, k.inv_inertia_world(rn))
        dl=-C/(c.w[idx]+wb+alpha_t)
        self.last_attach_dl=dl
        c.p[idx]=add(c.p[idx], mul(n,c.w[idx]*dl))
        P=mul(n,-dl)  # impulso no corpo (direção oposta)
        k.x=add(k.x, mul(P,1/k.d.mass))
        dth=k.inv_inertia_world(cross(r,P))
        dq=qmul((0.0,dth[0],dth[1],dth[2]),k.q)
        k.q=qnorm(tuple(k.q[i]+0.5*dq[i] for i in range(4)))
    # medidas
    def elevation(self):
        b=self.kite.world_point(self.kite.d.tow); d=sub(b,self.hand)
        return math.degrees(math.atan2(d[1], math.hypot(d[0],d[2])))
    def line_length(self):
        L=self.line; return sum(length(sub(L.p[i+1],L.p[i])) for i in range(L.n-1)) 
