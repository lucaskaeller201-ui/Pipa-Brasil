import math, sim2
from sim2 import *
from bot import nose_angle, sky, wrap
from exp12 import mk
DT=1/120
def run(w,s):
    for _ in range(round(s/DT)): w.step(DT)
for sb,sm,g,yt in [(2.5,240,4,150),(2.5,240,4,300),(3,260,4.5,300)]:
  res=[]; rr=[]
  for seed in [2,3,4,5]:
    w=mk(sb,sm,seed); sim2.YAW_TAUT=yt; run(w,12)
    w.inp={'haul':-g}; rates=[]
    for i in range(6):
        b=nose_angle(w); run(w,0.2); rates.append(round(wrap(nose_angle(w)-b)/0.2))
    w.inp={}
    b0=nose_angle(w); w.pilot.command('puxao',w.t); t=0; w.inp={'haul':6.0}
    while t<0.5 and w.tension<2.5: w.step(DT); t+=DT
    b1=nose_angle(w); w.inp={'haul':3.0}; run(w,0.4); b2=nose_angle(w)
    res.append((round(b0),round(b1),round(b2),round(t,2),round(sky(w)[1]))); rr.append(rates)
  print(sb,sm,g,yt,res); print('  ',rr)
