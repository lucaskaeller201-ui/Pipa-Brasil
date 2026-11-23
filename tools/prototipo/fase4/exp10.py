import math, sim2
from sim2 import *
from bot import nose_angle, sky, wrap
import exp8
from exp8 import run
DT=1/120
def mk(tref, sb=1.5, turb=0.15, seed=2):
    sim2.YAW_TAUT=40; sim2.K_SIDE=4; sim2.SPIN_MAX=math.radians(170)
    kd=KiteDef(dihedral_deg=0.0); kd_enable_flex(kd, t_ref=tref); kd.spin_bias=sb
    sim2.K_BOW=0.0; sim2.SPIN_Q=1.0; sim2.SPIN_L=0.3
    w=World(Wind(5.0,turbulence=turb,seed=seed), kd, line_len=30, elev_deg=45, segs=24, tail=True, substeps=4); w.pilot=Pilot()
    return w
if __name__=="__main__":
 for tref in [1.2, 2.5, 4.0]:
     for sb in [1.5, 3.0]:
         w=mk(tref,sb); run(w,12); hov=[0]
         run(w,6,lambda w: hov.__setitem__(0,max(hov[0],abs(nose_angle(w)))))
         el0=sky(w)[1]
         w.inp={'haul':-3.0}; rates=[]
         for i in range(10):
             b=nose_angle(w); run(w,0.2); rates.append(round(wrap(nose_angle(w)-b)/0.2))
         w.inp={}
         print(f"tref {tref} sb {sb}: parada<={hov[0]:.0f} el {el0:.0f} T={w.tension:.1f} | dando linha {rates} el fim {sky(w)[1]:.0f}")
