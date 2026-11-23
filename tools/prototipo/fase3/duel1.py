from duel import *
# Teste 1: duas pipas paradas com as linhas cruzadas (sem piloto)
A=make((-4,0,0),18,False); B=make((4,0,0),-18,False)
t0=time.time()
for k in range(round(10/DT)):
    step([A,B],DT,0.0)
    if k%120==0:
        print("t%4.1f elevA %5.1f elevB %5.1f kiteA x %5.1f kiteB x %5.1f dist %.3f contato_subpassos %d"%(A.t,A.elevation(),B.elevation(),A.kite.x[0],B.kite.x[0],min_dist(A.line,B.line),STATS['contacts']))
print("tempo",round(time.time()-t0))
