import sys
S=[]
M=[]
L=[]
W={}
ST=['']
IT=[]
def push(x): S.append(x)
def pop(): return S.pop()
def dot(): sys.stdout.write(str(pop())+chr(32))
def _emit(): sys.stdout.write(chr(pop()))
def _cr(): sys.stdout.write(chr(10))
def pr(s): sys.stdout.write(s[:-1])
def I(s):
 ST.append(s)
 return len(ST)-1
def _token():
 if not IT:
  IT.append(iter(open(sys.argv[1]).read().split()))
 for t in IT[0]:
  push(I(t))
  return
 push(0)
def _hdot(): sys.stdout.write(ST[pop()])
def _heq(): b=pop();push(-1 if ST[pop()]==ST[b] else 0)
def _h2n():
 try:
  push(int(ST[pop()],10))
  push(-1)
 except:
  push(0)
  push(0)
def _add(): b=pop();push(pop()+b)
def _sub(): b=pop();push(pop()-b)
def _mul(): b=pop();push(pop()*b)
def _div(): b=pop();push(pop()//b)
def _mod(): b=pop();push(pop()%b)
def _neg(): push(-pop())
def _eq(): push(-1 if pop()==pop() else 0)
def _lt(): b=pop();push(-1 if pop()<b else 0)
def _gt(): b=pop();push(-1 if pop()>b else 0)
def _dup(): S.append(S[-1])
def _drop(): S.pop()
def _swap(): S[-2],S[-1]=S[-1],S[-2]
def _over(): S.append(S[-2])
def _rot(): S.append(S.pop(-3))
def _store(): a=pop();M[a]=pop()
def _fetch(): push(M[pop()])
def _do(): s=pop();l=pop();L.append([s,l])
def _loop():
 L[-1][0]+=1
 if L[-1][0]<L[-1][1]: return False
 L.pop()
 return True
def _mkvar():
 M.append(0)
 a=len(M)-1
 return lambda: push(a)
def _f():
 pass
 push(0 )
 push(1 )
 push(10 )
 push(0 )
 _do()
 while True:
  pass
  _over()
  dot()
  _swap()
  _over()
  _add()
  if _loop(): break
 _drop()
 _drop()
W["fib10"]=_f
W["fib10"]()
_cr()
