import math, sim2, bot
from bot import nose_angle, sky, wrap
from exp4 import run
DT=1/120
def test(desb,label,yt=20,seeds=(1,2,3),interval=0.6):
  sim2.DESB=desb
  for seed in seeds:
    w=bot.make_world(True,0.15,seed); sim2.YAW_TAUT=yt
    run(w,15)
    g=[]; el=[]
    for k in range(10):
        a=nose_angle(w); w.pilot.command('desbicar',w.t); run(w,interval); g.append(round(wrap(nose_angle(w)-a))); el.append(round(sky(w)[1]))
    print(f"{label:24s} s{seed}: giros {g} el {el}")
test([(0,0.30,0.40,5.0),(0.30,0.15,-0.40,5.0),(0.45,0.4,0.0,1.5)],"atual 0.30")
test([(0,0.40,0.45,5.0),(0.40,0.15,-0.40,5.0),(0.55,0.4,0.0,1.5)],"folga 0.40")
test([(0,0.40,0.45,5.0),(0.40,0.30,0.0,3.0)],"folga 0.40 sem puxao")
