import sys, time
from bot import *
def fly(level, secs, seed=1, turb=0.15, tailless=True, verbose=False, gust_every=20.0):
    w=make_world(tailless,turb,seed)
    b=Bot(LEVELS[level], seed)
    low=99; below20=0; ground=0; n=0; err=[]; lado=[]
    rng=random.Random(seed+100)
    for k in range(round(secs/DT)):
        t=k*DT
        if gust_every and k%round(gust_every/DT)==round(gust_every/DT)-1:
            w.wind.gust_t0=t; w.wind.gust_speed=rng.uniform(7,10); w.wind.gust_dur=3.0
        b.target_az = 25.0 if int(t//10)%2==0 else -25.0
        b.target_el = 45.0
        w.inp=b.update(w,t)
        if t>3 and t%10>6:
            err.append(abs(sky(w)[0]-b.target_az)); lado.append(sky(w)[0]*b.target_az>0)
        w.step(DT)
        el=sky(w)[1]; n+=1
        if t>5: low=min(low,el); below20+= el<20
        if w.kite.x[1]<0.6: ground+=1
        if verbose and k%240==0: print("  t%5.1f el %5.1f az %5.1f bico %+5.0f estado %s linha %.1f T %.2f"%(t,el,sky(w)[0],nose_angle(w),b.state,chain_total(w.line),w.tension))
    err.sort()
    return dict(lado_certo=round(sum(lado)/max(1,len(lado)),2), erro_az_mediano=round(err[len(err)//2],1) if err else None, min_el=round(low,1), frac_abaixo20=round(below20/n,3), chao_s=round(ground*DT,1), folgas=b.log['folgas'], linha=round(chain_total(w.line),1), el_final=round(sky(w)[1],1))
if __name__=="__main__":
    lvl=sys.argv[1] if len(sys.argv)>1 else 'dificil'; secs=float(sys.argv[2]) if len(sys.argv)>2 else 60
    t0=time.time(); print(lvl, fly(lvl,secs,verbose=True), "tempo %.0fs"%(time.time()-t0))
