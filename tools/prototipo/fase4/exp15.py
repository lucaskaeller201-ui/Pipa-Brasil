import math, sim2
from sim2 import *
from bot import nose_angle, sky, wrap
from exp12 import mk
DT=1/120
def run(w,s):
    for _ in range(round(s/DT)): w.step(DT)
for yt,sm,g,hs in [(80,300,5,4),(200,300,5,4),(200,250,4,4),(200,300,5,6)]:
  res=[]
  for seed in [2,3,4,5]:
    w=mk(3,sm,seed); sim2.YAW_TAUT=yt; run(w,12)
    w.inp={'haul':-g}; run(w,1.3); w.inp={}
    b0=nose_angle(w); w.pilot.command('puxao',w.t); w.inp={'haul':hs}
    run(w,0.15); b1=nose_angle(w); run(w,0.35); b2=nose_angle(w); T=w.tension
    res.append((round(b0),round(b1),round(b2),round(T,1)))
  print(yt,sm,g,hs,res)
