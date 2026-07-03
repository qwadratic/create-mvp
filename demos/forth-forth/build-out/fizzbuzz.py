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
def _f():
 pass
 push(16 )
 push(1 )
 _do()
 while True:
  pass
  push(L[-1][0])
  push(15 )
  _mod()
  push(0 )
  _eq()
  if pop()!=0:
   pass
   pr('''FizzBuzz"''')
  else:
   pass
   push(L[-1][0])
   push(3 )
   _mod()
   push(0 )
   _eq()
   if pop()!=0:
    pass
    pr('''Fizz"''')
   else:
    pass
    push(L[-1][0])
    push(5 )
    _mod()
    push(0 )
    _eq()
    if pop()!=0:
     pass
     pr('''Buzz"''')
    else:
     pass
     push(L[-1][0])
     dot()
  _cr()
  if _loop(): break
W["fizzbuzz"]=_f
W["fizzbuzz"]()
