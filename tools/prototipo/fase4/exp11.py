import math, sim2
from sim2 import *
import bot
from bot import nose_angle, sky, wrap, Bot, LEVELS
from exp10 import mk
DT=1/120
for lvl in ['facil','normal','dificil']:
    for seed in [2,3]:
        w=mk(2.5,1.5,0.15,seed); b=Bot(LEVELS[lvl], seed); 
        mn=90; chao=0
        for i in range(round(60/DT)):
            w.inp=b.update(w,w.t) or w.inp
            w.step(DT)
            el=sky(w)[1]
            if i>600: mn=min(mn,el)
            if w.kite.x[1]<0.3: chao+=DT
        print(f"bot {lvl} s{seed}: el min {mn:.0f} chão {chao:.1f}s linha {chain_total(w.line):.0f}")
