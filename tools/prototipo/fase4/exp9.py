from exp8 import *
for g in [3.0,4.0]:
    for sb in [1.0,2.0]:
        trial(f"rab sb{sb} dá {g}", True, sb, 40, 4, 200, give=g)
