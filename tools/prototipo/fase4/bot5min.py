from botrun import *
import sys
lvl=sys.argv[1]
for seed in (1,2):
    r=fly(lvl,300,seed=seed)
    print(lvl,"semente",seed,{k:r[k] for k in ('min_el','frac_abaixo20','chao_s','linha','folgas')},flush=True)
