import math, sim2
from bot import make_world, nose_angle, sky, wrap
DT=1/120
def run(w,s):
    for _ in range(round(s/DT)): w.step(DT)
def trial(yt, desb, label, turb=0.0, seed=1, interval=0.6):
    sim2.DESB=desb
    w=make_world(True,turb,seed); sim2.YAW_TAUT=yt
    run(w,12)
    hn=0
    for i in range(round(6/DT)):
        w.step(DT); hn=max(hn,abs(nose_angle(w)))
    giros=[]; n=0
    while abs(nose_angle(w))<60 and n<12:
        a=nose_angle(w); w.pilot.command('desbicar',w.t); run(w,interval); n+=1; giros.append(round(wrap(nose_angle(w)-a)))
    b0=nose_angle(w); p0=sky(w); tr=[]
    w.inp={'haul':3.0}
    for i in range(6):
        q=sky(w); run(w,0.2); r=sky(w); tr.append(round(math.degrees(math.atan2(r[0]-q[0], r[1]-q[1]))))
    w.inp={}
    p1=sky(w); b1=nose_angle(w)
    run(w,3.0)
    print(f"{label:22s} parada<= {hn:.0f} | toques {n} giros {giros} | puxada bico {b0:.0f}->{b1:.0f} rumo {tr} az {p1[0]-p0[0]:.0f} el {p1[1]-p0[1]:.0f} | 3s: bico {nose_angle(w):.0f} el {sky(w)[1]:.0f}")
base=[(0,0.30,0.40,5.0),(0.30,0.15,-0.40,5.0),(0.45,0.4,0.0,1.5)]
if __name__=="__main__":
    for yt in [0,10,20,40]:
        trial(yt, base, f"yt={yt}")
        trial(yt, base, f"yt={yt} turb", 0.15, 2)
    