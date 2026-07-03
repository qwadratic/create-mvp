import sys
S=[]
M=[]
L=[]
W={}
def push(x): S.append(x)
def pop(): return S.pop()
def dot(): sys.stdout.write(str(pop())+' ')
def _emit(): sys.stdout.write(chr(pop()))
def _cr(): sys.stdout.write(chr(10))
def pr(s): sys.stdout.write(s[:-1])
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
W["a"]=_mkvar()
W["b"]=_mkvar()
W["r"]=_mkvar()
W["row"]=_mkvar()
def _f():
 pass
 W["b"]()
 _store()
 W["a"]()
 _store()
 push(1 )
 W["r"]()
 _store()
 while True:
  pass
  W["b"]()
  _fetch()
  push(2 )
  _mod()
  W["a"]()
  _fetch()
  push(2 )
  _mod()
  _gt()
  if pop()!=0:
   pass
   push(0 )
   W["r"]()
   _store()
  W["a"]()
  _fetch()
  push(2 )
  _div()
  W["a"]()
  _store()
  W["b"]()
  _fetch()
  push(2 )
  _div()
  W["b"]()
  _store()
  W["b"]()
  _fetch()
  push(0 )
  _eq()
  if pop()!=0: break
 W["r"]()
 _fetch()
W["odd?"]=_f
def _f():
 pass
 push(16 )
 push(0 )
 _do()
 while True:
  pass
  push(L[-1][0])
  W["row"]()
  _store()
  W["row"]()
  _fetch()
  push(1 )
  _add()
  push(0 )
  _do()
  while True:
   pass
   W["row"]()
   _fetch()
   push(L[-1][0])
   W["odd?"]()
   if pop()!=0:
    pass
    push(42 )
    _emit()
   else:
    pass
    push(32 )
    _emit()
   if _loop(): break
  _cr()
  if _loop(): break
W["sier"]=_f
W["sier"]()
