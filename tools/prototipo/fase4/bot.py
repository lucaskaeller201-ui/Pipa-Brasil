# Protótipo do bot piloto (Fase 4). Só usa o que um pipeiro percebe:
# posição da pipa no céu (azimute, elevação), para onde o bico aponta,
# tensão sentida na mão e comprimento de linha. Com ruído e atraso.
import math, random
import sim2
from sim2 import *

def nose_angle(w):
    n=qrot(w.kite.q,(0,1,0)); line=norm(sub(w.kite.x,w.hand))
    up=norm(sub((0,1,0), mul(line, dot((0,1,0),line)))); right=norm(cross(line,up))
    return math.degrees(math.atan2(dot(n,right), dot(n,up)))
def sky(w):
    d=sub(w.kite.world_point(w.kite.d.tow), w.hand)
    return (math.degrees(math.atan2(d[0], -d[2])), math.degrees(math.atan2(d[1], math.hypot(d[0],d[2]))))
def mk2(asym=0.0, turb=0.0, seed=1):
    kd=KiteDef(dihedral_deg=0.0); kd_enable_flex(kd)
    w=World(Wind(5.0,turbulence=turb,seed=seed), kd, line_len=30, segs=24, tail=False, substeps=4); w.pilot=Pilot(); return w
DT=1/120
def wrap(a): return (a+540)%360-180

class Difficulty:
    def __init__(self, reaction=0.12, noise_deg=2.0, noise_tension=0.1, tol=12.0, lead=0.10, decide_hz=30):
        self.reaction=reaction; self.noise_deg=noise_deg; self.noise_tension=noise_tension
        self.tol=tol; self.lead=lead; self.decide_dt=1.0/decide_hz
LEVELS={
 'facil':Difficulty(0.30,6.0,0.4,22.0,0.05,10),
 'normal':Difficulty(0.20,4.0,0.25,16.0,0.08,15),
 'dificil':Difficulty(0.12,2.0,0.1,12.0,0.10,30),
 'pro':Difficulty(0.08,1.0,0.05,9.0,0.12,60),
}
class Perception:
    def __init__(self, diff, seed=1):
        self.d=diff; self.rng=random.Random(seed); self.buf=[]
    def observe(self, w, t):
        az,el=sky(w)
        s=dict(t=t, az=az, el=el, nose=nose_angle(w), tension=w.tension, line=chain_total(w.line))
        self.buf.append(s)
        while len(self.buf)>1 and self.buf[1]['t'] <= t-self.d.reaction: self.buf.pop(0)
        o=dict(self.buf[0]); g=self.rng.gauss
        o['az']+=g(0,self.d.noise_deg); o['el']+=g(0,self.d.noise_deg); o['nose']=wrap(o['nose']+g(0,self.d.noise_deg*1.5))
        o['tension']=max(0.0,o['tension']+g(0,self.d.noise_tension))
        return o

class Bot:
    def __init__(self, diff, seed=1, target_el=50.0, target_az=0.0, line_target=30.0):
        self.d=diff; self.p=Perception(diff,seed); self.state='voar'; self.t_state=0.0
        self.prev=None; self.rate=0.0; self.next_decision=0.0; self.inp={}
        self.target_el=target_el; self.target_az=target_az; self.line_target=line_target
        self.log={'folgas':0}
    def desired_heading(self, o):
        # três direções simples: diagonal para a esquerda, para a direita ou para cima.
        # Pipa baixa: para de manobrar e sobe.
        if o['el']<22: return 0.0
        daz=self.target_az-o['az']
        if daz>8: return 55.0
        if daz<-8: return -55.0
        return 0.0
    def update(self, w, t):
        o=self.p.observe(w,t)
        if self.prev is not None:
            dt=o['t']-self.prev['t']
            if dt>0: self.rate=0.7*self.rate+0.3*wrap(o['nose']-self.prev['nose'])/dt
        self.prev=o
        if t < self.next_decision: return self.inp
        self.next_decision=t+self.d.decide_dt
        hd=self.desired_heading(o); e=wrap(o['nose']-hd)
        pred=wrap(o['nose']+self.rate*(self.d.lead+self.d.reaction)-hd)
        inp={}
        if self.state=='voar':
            if abs(e)>self.d.tol*2 and t-self.t_state>0.25 and (abs(self.target_az-o['az'])>6 or abs(wrap(o['nose']))>60):
                self.state='folga'; self.t_state=t; self.log['folgas']+=1
        else:
            if abs(pred)<self.d.tol or t-self.t_state>1.5:
                self.state='voar'; self.t_state=t
        dist=abs(self.target_az-o['az']) if o['el']>=22 else 0.0
        if self.state=='folga':
            # solta a carretilha só no começo do giro (no máximo 0,25 s)
            inp={'afrouxar':1.0,'largar': t-self.t_state<0.25 and abs(pred)>self.d.tol*2 and o['line']<self.line_target+8}
        else:
            if abs(e)<self.d.tol and dist>6:
                # alinhada: recolher estica a linha e empurra a pipa para a frente
                inp={'recolher':True} if o['line']>self.line_target-8 else {'puxar':1.0}
            # segurança: bico para baixo e pipa baixa -> folga para ela endireitar
            if o['el']<15 and abs(wrap(o['nose']))>100: inp={'afrouxar':1.0}
            # controla o comprimento quando o bico aponta para cima
            if not inp and abs(wrap(o['nose']))<60 and o['line']>self.line_target: inp={'recolher':True}
            if abs(wrap(o['nose']))<25 and o['line']>self.line_target+2: inp={'recolher':True}
            if 'recolher' not in inp and abs(wrap(o['nose']))<100 and o['line']>self.line_target+6: inp={'recolher':True}
        # emergência: bico para baixo -> solta a carretilha para a pipa parar de mergulhar
        if abs(wrap(o['nose']))>110 and o['el']<40 and o['line']<self.line_target+25:
            inp=dict(inp); inp['largar']=True; inp.pop('recolher',None); inp['afrouxar']=1.0
        self.inp=inp
        return inp

def make_world(tailless=True, turb=0.15, seed=1, gusts=()):
    if tailless:
        sim2.K_BOW=0.0; sim2.SPIN_Q=1.0; sim2.SPIN_L=0.3
        w=mk2(0.0,turb,seed); w.kite.d.spin_bias=0.3
    else:
        sim2.K_BOW=0.0; sim2.SPIN_Q=0.0; sim2.SPIN_L=0.0
        w=World(Wind(5.0,turbulence=turb,seed=seed), KiteDef(), line_len=30, segs=24, tail=True, substeps=4); w.pilot=Pilot()
    for (t0,sp,du) in gusts:
        w.wind.gust_t0=t0; w.wind.gust_speed=sp; w.wind.gust_dur=du
    return w
