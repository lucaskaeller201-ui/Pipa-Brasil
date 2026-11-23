# 1.000 cruzamentos aleatórios: a linha B (vertical, pontas presas, movendo em z)
# atravessa a região da linha A (horizontal, pontas presas, flexível). Critério:
# o lado relativo nunca inverte e A é empurrada.
import random, math, sys
from contact import *
H=1/480; R=0.02; EA=600.0; MPM=0.0003
def make_line(a,b,n):
    pts=[add(a,mul(sub(b,a),i/n)) for i in range(n+1)]
    seg=length(sub(b,a))/n; m=MPM*seg
    w=[1/m]*(n+1); w[0]=0; w[-1]=0
    return Chain(pts,w,seg)
def solve_dist(c,h):
    at=(1/EA)*c.rest/(h*h)
    for i in range(len(c.p)-1):
        d=sub(c.p[i],c.p[i+1]); L=length(d)
        if L<1e-9: continue
        n=mul(d,1/L); ws=c.w[i]+c.w[i+1]+at
        dl=-(L-c.rest)/ws
        c.p[i]=add(c.p[i],mul(n,c.w[i]*dl)); c.p[i+1]=sub(c.p[i+1],mul(n,c.w[i+1]*dl))
def crossed_between(A,i,B,j):
    p1,q1=A.p[i],A.p[i+1]; p2,q2=B.p[j],B.p[j+1]
    s,t=closest_params(p1,q1,p2,q2)
    if not (1e-3<s<1-1e-3 and 1e-3<t<1-1e-3): return False
    nx=norm(cross(sub(q1,p1),sub(q2,p2)))
    if length(nx)<0.5: return False
    ca=add(p1,mul(sub(q1,p1),s)); cb=add(p2,mul(sub(q2,p2),t))
    pa0=add(A.pp[i],mul(sub(A.pp[i+1],A.pp[i]),s)); pb0=add(B.pp[j],mul(sub(B.pp[j+1],B.pp[j]),t))
    sd0=dot(sub(pa0,pb0),nx); sd1=dot(sub(ca,cb),nx)
    return sd0*sd1<0 and abs(sd0)>1e-4 and abs(sd1)>1e-4
def run_case(rng, verbose=False):
    ang=rng.uniform(0.3,math.pi-0.3)   # ângulo entre as linhas
    speed=rng.uniform(0.5,15.0)
    off=rng.uniform(-1.0,1.0)
    L=6.0; n=10
    A=make_line((-L/2,2,0),(L/2,2,0),n)
    dirB=(math.cos(ang),math.sin(ang),0)
    zstart=0.6
    B=make_line(add((off,2,zstart),mul(dirB,-L/2)),add((off,2,zstart),mul(dirB,L/2)),n)
    # B começa um pouco inclinada no plano xy e se move em -z atravessando o plano de A
    sign0=None
    travel=1.2; T=travel/speed; steps=int(T/H)+1
    for k in range(steps):
        z=zstart-speed*H*(k+1)
        for c in (A,B):
            for i in range(len(c.p)):
                c.pp[i]=c.p[i]
                if c.w[i]>0:
                    c.v[i]=add(c.v[i],(0,-9.81*H,0)); c.p[i]=add(c.p[i],mul(c.v[i],H))
        # pontas de B avançam
        for idx in (0,len(B.p)-1):
            B.p[idx]=(B.p[idx][0],B.p[idx][1],z)
        for it in range(4):
            solve_dist(A,H); solve_dist(B,H)
            for i in range(n):
                for j in range(n):
                    solve_pair_contact(A,i,B,j,R,H)
        for c in (A,B):
            for i in range(len(c.p)):
                c.v[i]=mul(sub(c.p[i],c.pp[i]),1/H)
                c.v[i]=mul(c.v[i],0.999)
        # travessia: algum par cruzou entre pp e p (depois do solver)?
        for i in range(n):
            for j in range(n):
                if crossed_between(A,i,B,j):
                    return False, "atravessou (ang %.2f vel %.1f off %.2f passo %d par %d,%d)"%(ang,speed,off,k,i,j)
    return True, ""
if __name__=="__main__":
    rng=random.Random(7); fails=[]
    N=int(sys.argv[1]) if len(sys.argv)>1 else 1000
    import time; t0=time.time()
    for c in range(N):
        ok,msg=run_case(rng)
        if not ok: fails.append(msg)
    print("casos",N,"falhas",len(fails),"tempo %.0fs"%(time.time()-t0))
    for m in fails[:10]: print("  ",m)
