# Desgaste: duas linhas esticadas cruzadas; B desliza sobre A. Quem rompe?
from contact import *
from test_cross import make_line, solve_dist, H, R
import math
def scenario(slide_speed, tension_pull, wear_k=0.1, secs=3.0):
    n=10; L=6.0
    A=make_line((-3,2,0),(3,2,0),n)
    B=make_line((0,-1,0.3),(0,5,0.3),n)
    # pré-tensão: encurta repouso
    for c in (A,B): c.rest*= (1-tension_pull/600.0)
    # B empurrada contra A: pontas de B deslocadas em -z (0.3 m) para apertar
    steps=int(secs/H); x=0.0
    for k in range(steps):
        t=k*H
        z=0.3-0.6*min(1.0,t/0.5)
        if t>0.5: x+=slide_speed*H
        for c in (A,B):
            for i in range(len(c.p)):
                c.pp[i]=c.p[i]
                if c.w[i]>0: c.p[i]=add(c.p[i],mul(c.v[i],H))
        B.p[0]=(x,-1,z); B.p[-1]=(x,5,z)
        for it in range(4):
            solve_dist(A,H); solve_dist(B,H)
            for i in range(n):
                for j in range(n): solve_pair_contact(A,i,B,j,R,H,wear_k)
        for c in (A,B):
            for i in range(len(c.p)): c.v[i]=mul(mul(sub(c.p[i],c.pp[i]),1/H),0.995)
    return max(A.wear), max(B.wear), sum(A.wear), sum(B.wear)
for v in (0.0,0.5,2.0):
    for T in (2.0,8.0):
        a,b,sa,sb=scenario(v,T)
        print("deslize %.1f m/s, pré-tensão %.0f N: desgaste máx A %.2f B %.2f (total A %.2f B %.2f)"%(v,T,a,b,sa,sb))
