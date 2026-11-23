import math, sim2
from sim2 import *
from bot import nose_angle, sky, wrap
DT=1/120
def run(w,s,f=None):
    for _ in range(round(s/DT)):
        w.step(DT)
        if f: f(w)
def mk(tail, sb, yt, ks, smax, turb=0.0, seed=1):
    sim2.YAW_TAUT=yt; sim2.K_SIDE=ks; sim2.SPIN_MAX=math.radians(smax)
    kd=KiteDef(dihedral_deg=0.0); kd_enable_flex(kd); kd.spin_bias=sb
    sim2.K_BOW=0.0; sim2.SPIN_Q=1.0; sim2.SPIN_L=0.3
    w=World(Wind(5.0,turbulence=turb,seed=seed), kd, line_len=30, elev_deg=45, segs=24, tail=tail, substeps=4); w.pilot=Pilot()
    return w
def trial(label, tail, sb, yt, ks, smax, give=2.0):
    w=mk(tail,sb,yt,ks,smax,0.15,2)
    run(w,12); hov=[0]
    run(w,6,lambda w: hov.__setitem__(0,max(hov[0],abs(nose_angle(w)))))
    # dá linha 2 s, mede giro
    rates=[]; a=nose_angle(w); w.inp={'haul':-give}; el0=sky(w)[1]
    for i in range(10):
        b=nose_angle(w); run(w,0.2); rates.append(round(wrap(nose_angle(w)-b)/0.2))
    w.inp={}
    # toque = puxão; trava e arranca
    b0=nose_angle(w); w.pilot.command('puxao',w.t); run(w,0.15); b1=nose_angle(w)
    p0=sky(w); tr=[]
    w.inp={'haul':3.0}
    for i in range(8):
        q=sky(w); run(w,0.25); r=sky(w); tr.append(round(math.degrees(math.atan2(r[0]-q[0], r[1]-q[1]))))
    w.inp={}
    p1=sky(w)
    print(f"{label:26s} parada<={hov[0]:.0f} | dando linha °/s {rates} el {el0:.0f}->{p0[1]:.0f} | toque bico {b0:.0f}->{b1:.0f} | puxada rumo {tr} bico fim {nose_angle(w):.0f} az {p1[0]-p0[0]:.0f} el {p1[1]-p0[1]:.0f}")
if __name__=="__main__":
  trial("sem rabiola atual", False, 0.3, 20, 0, 0)
  trial("sem rab side4 cap200", False, 0.3, 40, 4, 200)
  trial("rabiola sb0.3", True, 0.3, 40, 4, 200)
  trial("rabiola sb1.0", True, 1.0, 40, 4, 200)
  trial("rabiola sb2.0", True, 2.0, 40, 4, 200)
