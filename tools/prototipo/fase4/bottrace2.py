from botrun import *
w=make_world(True,0.15,1); b=Bot(LEVELS['dificil'],1)
for k in range(round(12/DT)):
    t=k*DT
    b.target_az = 25.0; b.target_el=45.0
    w.inp=b.update(w,t); w.step(DT)
    if k%15==0: print("t%5.2f el %5.1f az %5.1f bico %+5.0f desejado %+5.0f taxa %+5.0f %-5s linha %5.1f T %5.2f %s"%(t,sky(w)[1],sky(w)[0],nose_angle(w),b.desired_heading(b.prev),b.rate,b.state,chain_total(w.line),w.tension,w.inp))
