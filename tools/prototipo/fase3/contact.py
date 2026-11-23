# Protótipo do contato entre duas cadeias de partículas (linhas) com CCD.
import math, random
def add(a,b): return (a[0]+b[0],a[1]+b[1],a[2]+b[2])
def sub(a,b): return (a[0]-b[0],a[1]-b[1],a[2]-b[2])
def mul(a,s): return (a[0]*s,a[1]*s,a[2]*s)
def dot(a,b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a,b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(dot(a,a))
def norm(a):
    l=length(a); return (0.0,0.0,0.0) if l<1e-12 else mul(a,1/l)

def closest_params(p1,q1,p2,q2):
    # parâmetros s,t em [0,1] dos pontos mais próximos dos segmentos p1q1 e p2q2
    d1=sub(q1,p1); d2=sub(q2,p2); r=sub(p1,p2)
    a=dot(d1,d1); e=dot(d2,d2); f=dot(d2,r)
    if a<1e-12 and e<1e-12: return 0.0,0.0
    if a<1e-12: return 0.0, max(0.0,min(1.0,f/e))
    c=dot(d1,r)
    if e<1e-12: return max(0.0,min(1.0,-c/a)),0.0
    b=dot(d1,d2); den=a*e-b*b
    s=max(0.0,min(1.0,(b*f-c*e)/den)) if den>1e-12 else 0.0
    t=(b*s+f)/e
    if t<0: t=0.0; s=max(0.0,min(1.0,-c/a))
    elif t>1: t=1.0; s=max(0.0,min(1.0,(b-c)/a))
    return s,t

class Chain:
    def __init__(self,pts,inv_m,rest):
        self.p=list(pts); self.pp=list(pts); self.v=[(0,0,0)]*len(pts); self.w=list(inv_m); self.rest=rest
        self.wear=[0.0]*(len(pts)-1)

USE_CCD=True
def solve_pair_contact(A,i,B,j,radius,h,wear_k=0.0):
    """Restrição de contato entre segmento i de A e j de B. Devolve (corrigiu, impulso)."""
    p1,q1=A.p[i],A.p[i+1]; p2,q2=B.p[j],B.p[j+1]
    s,t=closest_params(p1,q1,p2,q2)
    ca=add(p1,mul(sub(q1,p1),s)); cb=add(p2,mul(sub(q2,p2),t))
    d=sub(ca,cb); dist=length(d)
    # normal geométrica (produto vetorial) para detectar travessia
    nx=norm(cross(sub(q1,p1),sub(q2,p2)))
    crossed=False
    if USE_CCD and length(nx)>0.5 and 1e-3<s<1-1e-3 and 1e-3<t<1-1e-3:
        # mesmo s,t na configuração anterior
        pa0=add(A.pp[i],mul(sub(A.pp[i+1],A.pp[i]),s)); pb0=add(B.pp[j],mul(sub(B.pp[j+1],B.pp[j]),t))
        sd0=dot(sub(pa0,pb0),nx); sd1=dot(d,nx)
        if sd0*sd1<0 and abs(sd0)>1e-6:
            crossed=True
            n=mul(nx, 1.0 if sd0>0 else -1.0)
            dist=sd1*(1.0 if sd0>0 else -1.0)  # negativo: penetrou
    if not crossed:
        if dist>=radius: return False,0.0
        n=mul(d,1/dist) if dist>1e-9 else (nx if length(nx)>0.5 else (0,1,0))
    C=dist-radius  # <0
    wa=A.w[i]*(1-s)**2+A.w[i+1]*s**2; wb=B.w[j]*(1-t)**2+B.w[j+1]*t**2
    wsum=wa+wb
    if wsum<1e-12: return False,0.0
    dl=-C/wsum
    A.p[i]=add(A.p[i],mul(n,A.w[i]*(1-s)*dl)); A.p[i+1]=add(A.p[i+1],mul(n,A.w[i+1]*s*dl))
    B.p[j]=sub(B.p[j],mul(n,B.w[j]*(1-t)*dl)); B.p[j+1]=sub(B.p[j+1],mul(n,B.w[j+1]*t*dl))
    if wear_k>0:
        force=dl/(h*h)
        va=add(mul(A.v[i],1-s),mul(A.v[i+1],s)); vb=add(mul(B.v[j],1-t),mul(B.v[j+1],t))
        vrel=sub(va,vb); vt=sub(vrel,mul(n,dot(vrel,n))); slide=length(vt)
        A.wear[i]+=wear_k*force*slide*h; B.wear[j]+=wear_k*force*slide*h
    return True,dl

def side_sign(A,i,B,j):
    s,t=closest_params(A.p[i],A.p[i+1],B.p[j],B.p[j+1])
    ca=add(A.p[i],mul(sub(A.p[i+1],A.p[i]),s)); cb=add(B.p[j],mul(sub(B.p[j+1],B.p[j]),t))
    nx=cross(sub(A.p[i+1],A.p[i]),sub(B.p[j+1],B.p[j]))
    return 1 if dot(sub(ca,cb),nx)>=0 else -1
