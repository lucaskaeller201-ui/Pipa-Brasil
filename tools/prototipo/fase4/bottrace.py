from bot import *
import sys
turb=float(sys.argv[1]) if len(sys.argv)>1 else 0.15
w=make_world(True,turb,1); b=Bot(LEVELS['dificil'],1)
use_bot = len(sys.argv)<=2
for k in range(round(3.0/DT)):
    t=k*DT
    if use_bot: w.inp=b.update(w,t)
    w.step(DT)
    if k%12==0:
        dmin,dmax,_=w.kite.d.flex; bf=(w.kite.d.delta-dmin)/(dmax-dmin)
        print("t%.2f el %5.1f az %5.1f bico %+5.0f taxa %+6.0f°/s estado %-5s T %.2f vareta %.2f inp %s"%(t,sky(w)[1],sky(w)[0],nose_angle(w),b.rate,b.state,w.tension,bf,w.inp))
