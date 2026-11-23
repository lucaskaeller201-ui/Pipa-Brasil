import math, sim2
from sim2 import *
from bot import nose_angle, sky, wrap
from exp8 import run
DT=1/120
def mk(sb, smax, seed=2):
    sim2.YAW_TAUT=80; sim2.K_SIDE=4; sim2.SPIN_MAX=math.radians(smax)
    kd=KiteDef(dihedral_deg=0.0); kd_enable_flex(kd, t_ref=2.5); kd.spin_bias=sb
    sim2.K_BOW=0.0; sim2.SPIN_Q=1.0; sim2.SPIN_L=0.3
    w=World(Wind(5.0,turbulence=0.15,seed=seed), kd, line_len=30, elev_deg=45, segs=24, tail=True, substeps=4); w.pilot=Pilot()
    return w
for sb,sm,g in [(1.5,170,3),(3,300,5),(5,300,5),(5,360,6)]:
    w=mk(sb,sm); run(w,12); hov=[0]
    run(w,5,lambda w: hov.__setitem__(0,max(hov[0],abs(nose_angle(w)))))
    w.inp={'haul':-g}; rates=[]
    for i in range(8):
        b=nose_angle(w); run(w,0.2); rates.append(round(wrap(nose_angle(w)-b)/0.2))
    w.inp={}; b0=nose_angle(w); w.pilot.command('puxao',w.t); run(w,0.15); b1=nose_angle(w)
    print(f"sb{sb} max{sm} dá{g}: parada<={hov[0]:.0f} giro {rates} toque {b0:.0f}->{b1:.0f} el {sky(w)[1]:.0f}")
