using ApproxFun,Base.Test

import ApproxFun:interlace,Multiplication


d=Interval()
D=Derivative(d);
B=ldirichlet();
Bn=lneumann();
A=[B 0;
   0 B;
   D-I 2I;
   0I D+I];

f=Fun(x->[exp(x),cos(x)],d)


b=Any[0.,0.,f...]
f1,f2=vec(f)
u=A\b
u1=vec(u)[1];u2=vec(u)[2];

@test norm(u1'-u1+2u2-f1)<10eps()
@test norm(u2'+u2-f2)<10eps()

Ai=Operator(A)
u=Ai\b
u1=vec(u)[1];u2=vec(u)[2];

@test norm(u1'-u1+2u2-f1)<10eps()
@test norm(u2'+u2-f2)<10eps()





A=[B 0;
   Bn 0;
   0 B;
   D^2-I 2I;
   0 D+I];


b=Any[0.,0.,0.,f...]


u=A\b
u1=vec(u)[1];u2=vec(u)[2];


@test norm(differentiate(u1,2)-u1+2u2-f1)<2eps()
@test norm(u2'+u2-f2)<2eps()

Ai=Operator(A)
u=Ai\b
u1=vec(u)[1];u2=vec(u)[2];


@test norm(u1''-u1+2u2-f1)<2eps()
@test norm(u2'+u2-f2)<2eps()






## Matrix exponential

n=4
d=fill(Interval(0.,1.),n)
B=Evaluation(d,0.)
D=Derivative(d)
A=rand(n,n)
L=[B;D-A]
u=L\eye(n)
@test norm(evaluate(u,1.)-expm(A))<eps(1000.)


n=4
d=fill(Interval(0.,1.),n)
B=Evaluation(d,0.)
D=Derivative(d)
A=rand(n,n)
L=[B;D-A]
u=L\eye(2)
@test norm(evaluate(u,1.)-expm(A)[:,1:2])<eps(1000.)




## Multiplication

d = Interval()
t=Fun(identity,d)
f = devec([t^2, sin(t)])
@test norm(((Derivative(space(f))*f)-Fun(t->[2t,cos(t)])).coefficients)<100eps()
@test norm((([1 2;3 4]*f)-Fun(t->[t^2+2sin(t),3t^2+4sin(t)])).coefficients)<100eps()



## Multiplication operator

Γ=Circle()∪Circle(0.5)
G=Fun(z->in(z,Γ[2])?[1 -z^(-1); 0 1]:
                   [z 0; 0 z^(-1)],Γ);
G1=demat(mat(G)[:,1])
M=Multiplication(G,space(G1))
u=M*G1
@test norm(u(exp(.1im))-[exp(.2im),0])<100eps()
@test norm(u(.5exp(.1im))-[1,0])<100eps()

# Vector operations
@test_approx_eq (Fun(x->[1., 2.]) + [2, 2])(0.) [3., 4.]



G=Fun(z->[-1 -3; -3 -1]/z +
         [ 2  2;  1 -3] +
         [ 2 -1;  1  2]*z,Circle())


@test G[1,1](exp(0.1im)) == G(exp(0.1im))[1,1]

F̃ = (G-I)[:,1]
F=Fun((G-I)[:,1])

@test_approx_eq F(exp(0.1im)) [-exp(-0.1im)+1+2exp(0.1im);-3exp(-0.1im)+1+1exp(0.1im)]
@test_approx_eq Fun(F̃,space(F))(exp(0.1im)) [-exp(-0.1im)+1+2exp(0.1im);-3exp(-0.1im)+1+1exp(0.1im)]

@test coefficients(F̃,space(F)) == F.coefficients
@test Fun(F̃,space(F)) == F





## Check conversion

f=Fun(t->[cos(t) 0;sin(t) 1],[-π,π])
g=Fun(f,Space(PeriodicInterval(-π,π)))
@test_approx_eq g(.1) f(.1)



## Operator * Matrix

D=Derivative()

u=D*[Fun(exp) Fun(cos)]
@test_approx_eq u(0.1) [exp(0.1) -sin(0.1)]
