import math, sim2
from sim2 import *
from bot import nose_angle, sky, wrap
from exp8 import run
from exp12 import mk
DT=1/120
for yt,cmd in [(80,'puxao'),(200,'puxao'),(200,'arrancao'),(400,'arrancao')]:
  res=[]
  for seed in [2,3,4]:
    w=mk(3,300,seed); sim2.YAW_TAUT=yt; run(w,12)
    w.inp={'haul':-5}; run(w,1.3); w.inp={}
    b0=nose_angle(w); w.pilot.command(cmd,w.t); run(w,0.1); b1=nose_angle(w); run(w,0.2); b2=nose_angle(w)
    res.append((round(b0),round(b1),round(b2)))
  print(yt,cmd,res)
