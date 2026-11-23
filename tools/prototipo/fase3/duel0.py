from duel import *
for az in (0,18):
    A=make((0,0,0),az,False)
    for k in range(round(10/DT)): step([A],DT,0.0)
    print("sozinha az",az,"elev %.1f x %.1f"%(A.elevation(),A.kite.x[0]))
A=make((-4,0,0),18,False); B=make((4,0,0),-18,False)
contact.USE_CCD=True
for k in range(round(10/DT)):
    h=DT/4
    for s in range(4):
        for w in (A,B): part1(w,h)
        for w in (A,B): part2(w,h)
        for w in (A,B): w.t+=h
print("duas sem contato: elevA %.1f elevB %.1f"%(A.elevation(),B.elevation()))
