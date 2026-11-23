from sweep2 import contact_time
for LB in (30,25):
    for dy in (0.6,0.3,-0.3,-0.6):
        ts=[round(contact_time(18,30,LB,(0,dy,dz))[0],2) for dz in (-0.35,0.0,0.3)]
        print("LB %d A deslocada dy %+.1f: contato %s"%(LB,dy,ts), flush=True)
