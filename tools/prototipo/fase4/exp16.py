import math, sim2
from sim2 import *
from bot import nose_angle, sky, wrap
from exp12 import mk
DT=1/120
def run(w,s):
    for _ in range(round(s/DT)): w.step(DT)
for sb,sm,fr in [(3,300,0.3),(3,300,0.1),(5,300,0.1),(5,400,0.1)]:
  sim2.GIVE_FRIC=fr; res=[]; rr=[]
  for seed in [2,3,4]:
    w=mk(sb,sm,seed); sim2.YAW_TAUT=200; run(w,12); L0=chain_total(w.line)
    w.inp={'haul':-5}; rates=[]
    for i in range(6):
        b=nose_angle(w); run(w,0.2); rates.append(round(wrap(nose_angle(w)-b)/0.2))
    w.inp={}; dL=chain_total(w.line)-L0
    b0=nose_angle(w); w.pilot.command('puxao',w.t); w.inp={'haul':3}
    run(w,0.15); b1=nose_angle(w); run(w,0.35); b2=nose_angle(w)
    res.append((round(b0),round(b1),round(b2),round(w.tension,1),round(dL,1),round(sky(w)[1]))); rr.append(rates)
  print(sb,sm,fr,res); print('   giros',rr)
