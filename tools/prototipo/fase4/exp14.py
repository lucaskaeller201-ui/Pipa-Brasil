import math, sim2
from sim2 import *
from bot import nose_angle, sky, wrap
from exp12 import mk
DT=1/120
def run(w,s):
    for _ in range(round(s/DT)): w.step(DT)
for yt in [80,200]:
  res=[]
  for seed in [2,3,4,5]:
    w=mk(3,300,seed); sim2.YAW_TAUT=yt; run(w,12)
    w.inp={'haul':-5}; run(w,1.3); w.inp={}
    b0=nose_angle(w); w.pilot.command('puxao',w.t); t=0
    w.inp={'haul':6.0}
    while t<0.4 and w.tension<2.5:
        w.step(DT); t+=DT
    w.inp={}; b1=nose_angle(w); run(w,0.3); b2=nose_angle(w)
    res.append((round(b0),round(b1),round(b2),round(t,2)))
  print(yt,res)
