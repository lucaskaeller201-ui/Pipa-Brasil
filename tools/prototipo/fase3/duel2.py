from duel import *
def run(mode, secs=4.0):
    A=make((0,0,0),18,True); B=make((8,0,0),-18,False)
    STATS['contacts']=0; STATS['fmax']=0
    ev=[]
    for k in range(round(secs/DT)):
        t=k*DT
        if mode=='largar': A.inp={'largar':True}
        elif mode=='dar': A.inp={'dar':True}
        elif mode=='recolher': A.inp={'recolher':True}
        elif mode=='puxao' and k==60: A.pilot.command('puxao',A.t)
        else: A.inp={}
        step([A,B],DT,1.0,strength=1e9,events=ev)
    a,_=worst(A.line); b,_=worst(B.line)
    return a, sum(getattr(A.line,'bins',{}).values()), b, sum(getattr(B.line,'bins',{}).values()), STATS['contacts']*DT/4, STATS['fmax']
for m in ('parado','largar','dar','recolher','puxao'):
    a,sa,b,sb,tc,fm=run(m)
    print("%-9s desgaste máx A %.3f (soma %.3f) | B %.3f (soma %.3f) | contato %.2f s, força máx %.1f N"%(m,a,sa,b,sb,tc,fm))
