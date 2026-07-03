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
W["depth"]=_mkvar()
W["defname"]=_mkvar()
W["sqh"]=_mkvar()
W["dqh"]=_mkvar()
def _f():
 pass
 push(34 )
 _emit()
W["q"]=_f
def _f():
 pass
 push(39 )
 _emit()
 push(39 )
 _emit()
 push(39 )
 _emit()
W["q3"]=_f
def _f():
 pass
 push(32 )
 _emit()
W["sp"]=_f
def _f():
 pass
 while True:
  pass
  _dup()
  push(0 )
  _gt()
  if pop()!=0:
   pass
   push(32 )
   _emit()
   push(1 )
   _sub()
   push(0 )
  else:
   pass
   push(-1 )
  if pop()!=0: break
 _drop()
W["spaces"]=_f
def _f():
 pass
 W["depth"]()
 _fetch()
 W["spaces"]()
W["ind"]=_f
def _f():
 pass
 W["depth"]()
 _fetch()
 push(1 )
 _add()
 W["depth"]()
 _store()
W["depth+"]=_f
def _f():
 pass
 W["depth"]()
 _fetch()
 push(1 )
 _sub()
 W["depth"]()
 _store()
W["depth-"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''pass"''')
 _cr()
W["passln"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''push("''')
 dot()
 pr(r''')"''')
 _cr()
W["do-num"]=_f
def _f():
 pass
 _token()
 W["defname"]()
 _store()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_f():"''')
 _cr()
 push(1 )
 W["depth"]()
 _store()
 W["passln"]()
W["do-colon"]=_f
def _f():
 pass
 push(0 )
 W["depth"]()
 _store()
 pr(r'''W["''')
 W["q"]()
 W["defname"]()
 _fetch()
 _hdot()
 W["q"]()
 pr(r''']=_f"''')
 _cr()
W["do-semi"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''pop()!=0:"''')
 _cr()
 W["depth+"]()
 W["passln"]()
W["do-if"]=_f
def _f():
 pass
 W["depth-"]()
 W["ind"]()
 pr(r'''else:"''')
 _cr()
 W["depth+"]()
 W["passln"]()
W["do-else"]=_f
def _f():
 pass
 W["depth-"]()
W["do-then"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''while"''')
 W["sp"]()
 pr(r'''True:"''')
 _cr()
 W["depth+"]()
 W["passln"]()
W["do-begin"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''pop()!=0:"''')
 W["sp"]()
 pr(r'''break"''')
 _cr()
 W["depth-"]()
W["do-until"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''_do()"''')
 _cr()
 W["ind"]()
 pr(r'''while"''')
 W["sp"]()
 pr(r'''True:"''')
 _cr()
 W["depth+"]()
 W["passln"]()
W["do-do"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''_loop():"''')
 W["sp"]()
 pr(r'''break"''')
 _cr()
 W["depth-"]()
W["do-loop"]=_f
def _f():
 pass
 _token()
 W["ind"]()
 pr(r'''W["''')
 W["q"]()
 _hdot()
 W["q"]()
 pr(r''']=_mkvar()"''')
 _cr()
W["do-var"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''W["''')
 W["q"]()
 _hdot()
 W["q"]()
 pr(r''']()"''')
 _cr()
W["do-call"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''pr(r"''')
 W["q3"]()
 _token()
 _hdot()
 W["q3"]()
 pr(r''')"''')
 _cr()
W["do-str"]=_f
def _f():
 pass
 W["ind"]()
 pr(r'''push(I(r"''')
 W["q3"]()
 _token()
 _hdot()
 W["q3"]()
 pr(r'''[:-1]))"''')
 _cr()
W["do-squote"]=_f
def _f():
 pass
 while True:
  pass
  _token()
  _dup()
  push(0 )
  _eq()
  if pop()!=0:
   pass
   _drop()
   push(-1 )
  else:
   pass
   _dup()
   push(I(r''':"'''[:-1]))
   _heq()
   if pop()!=0:
    pass
    _drop()
    W["do-colon"]()
    push(-1 )
   else:
    pass
    _drop()
    push(0 )
  if pop()!=0: break
W["do-bslash"]=_f
def _f():
 pass
 while True:
  pass
  _token()
  _dup()
  push(0 )
  _eq()
  if pop()!=0:
   pass
   _drop()
   push(-1 )
  else:
   pass
   push(I(r''')"'''[:-1]))
   _heq()
   if pop()!=0:
    pass
    push(-1 )
   else:
    pass
    push(0 )
  if pop()!=0: break
W["do-paren"]=_f
def _f():
 pass
 pr(r'''import"''')
 W["sp"]()
 pr(r'''sys"''')
 _cr()
 pr(r'''S=[]"''')
 _cr()
 pr(r'''M=[]"''')
 _cr()
 pr(r'''L=[]"''')
 _cr()
 pr(r'''W={}"''')
 _cr()
 pr(r'''ST=['']"''')
 _cr()
 pr(r'''IT=[]"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''push(x):"''')
 W["sp"]()
 pr(r'''S.append(x)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''pop():"''')
 W["sp"]()
 pr(r'''return"''')
 W["sp"]()
 pr(r'''S.pop()"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''dot():"''')
 W["sp"]()
 pr(r'''sys.stdout.write(str(pop())+chr(32))"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_emit():"''')
 W["sp"]()
 pr(r'''sys.stdout.write(chr(pop()))"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_cr():"''')
 W["sp"]()
 pr(r'''sys.stdout.write(chr(10))"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''pr(s):"''')
 W["sp"]()
 pr(r'''sys.stdout.write(s[:-1])"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''I(s):"''')
 _cr()
 W["sp"]()
 pr(r'''ST.append(s)"''')
 _cr()
 W["sp"]()
 pr(r'''return"''')
 W["sp"]()
 pr(r'''len(ST)-1"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_token():"''')
 _cr()
 W["sp"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''not"''')
 W["sp"]()
 pr(r'''IT:"''')
 _cr()
 W["sp"]()
 W["sp"]()
 pr(r'''IT.append(iter(open(sys.argv[1]).read().split()))"''')
 _cr()
 W["sp"]()
 pr(r'''for"''')
 W["sp"]()
 pr(r'''t"''')
 W["sp"]()
 pr(r'''in"''')
 W["sp"]()
 pr(r'''IT[0]:"''')
 _cr()
 W["sp"]()
 W["sp"]()
 pr(r'''push(I(t))"''')
 _cr()
 W["sp"]()
 W["sp"]()
 pr(r'''return"''')
 _cr()
 W["sp"]()
 pr(r'''push(0)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_hdot():"''')
 W["sp"]()
 pr(r'''sys.stdout.write(ST[pop()])"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_heq():"''')
 W["sp"]()
 pr(r'''b=pop();push(-1"''')
 W["sp"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''ST[pop()]==ST[b]"''')
 W["sp"]()
 pr(r'''else"''')
 W["sp"]()
 pr(r'''0)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_h2n():"''')
 _cr()
 W["sp"]()
 pr(r'''try:"''')
 _cr()
 W["sp"]()
 W["sp"]()
 pr(r'''push(int(ST[pop()],10))"''')
 _cr()
 W["sp"]()
 W["sp"]()
 pr(r'''push(-1)"''')
 _cr()
 W["sp"]()
 pr(r'''except:"''')
 _cr()
 W["sp"]()
 W["sp"]()
 pr(r'''push(0)"''')
 _cr()
 W["sp"]()
 W["sp"]()
 pr(r'''push(0)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_add():"''')
 W["sp"]()
 pr(r'''b=pop();push(pop()+b)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_sub():"''')
 W["sp"]()
 pr(r'''b=pop();push(pop()-b)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_mul():"''')
 W["sp"]()
 pr(r'''b=pop();push(pop()*b)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_div():"''')
 W["sp"]()
 pr(r'''b=pop();push(pop()//b)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_mod():"''')
 W["sp"]()
 pr(r'''b=pop();push(pop()%b)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_neg():"''')
 W["sp"]()
 pr(r'''push(-pop())"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_eq():"''')
 W["sp"]()
 pr(r'''push(-1"''')
 W["sp"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''pop()==pop()"''')
 W["sp"]()
 pr(r'''else"''')
 W["sp"]()
 pr(r'''0)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_lt():"''')
 W["sp"]()
 pr(r'''b=pop();push(-1"''')
 W["sp"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''pop()<b"''')
 W["sp"]()
 pr(r'''else"''')
 W["sp"]()
 pr(r'''0)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_gt():"''')
 W["sp"]()
 pr(r'''b=pop();push(-1"''')
 W["sp"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''pop()>b"''')
 W["sp"]()
 pr(r'''else"''')
 W["sp"]()
 pr(r'''0)"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_dup():"''')
 W["sp"]()
 pr(r'''S.append(S[-1])"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_drop():"''')
 W["sp"]()
 pr(r'''S.pop()"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_swap():"''')
 W["sp"]()
 pr(r'''S[-2],S[-1]=S[-1],S[-2]"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_over():"''')
 W["sp"]()
 pr(r'''S.append(S[-2])"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_rot():"''')
 W["sp"]()
 pr(r'''S.append(S.pop(-3))"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_store():"''')
 W["sp"]()
 pr(r'''a=pop();M[a]=pop()"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_fetch():"''')
 W["sp"]()
 pr(r'''push(M[pop()])"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_do():"''')
 W["sp"]()
 pr(r'''s=pop();l=pop();L.append([s,l])"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_loop():"''')
 _cr()
 W["sp"]()
 pr(r'''L[-1][0]+=1"''')
 _cr()
 W["sp"]()
 pr(r'''if"''')
 W["sp"]()
 pr(r'''L[-1][0]<L[-1][1]:"''')
 W["sp"]()
 pr(r'''return"''')
 W["sp"]()
 pr(r'''False"''')
 _cr()
 W["sp"]()
 pr(r'''L.pop()"''')
 _cr()
 W["sp"]()
 pr(r'''return"''')
 W["sp"]()
 pr(r'''True"''')
 _cr()
 pr(r'''def"''')
 W["sp"]()
 pr(r'''_mkvar():"''')
 _cr()
 W["sp"]()
 pr(r'''M.append(0)"''')
 _cr()
 W["sp"]()
 pr(r'''a=len(M)-1"''')
 _cr()
 W["sp"]()
 pr(r'''return"''')
 W["sp"]()
 pr(r'''lambda:"''')
 W["sp"]()
 pr(r'''push(a)"''')
 _cr()
W["pre"]=_f
def _f():
 pass
 _dup()
 _h2n()
 if pop()!=0:
  pass
  _swap()
  _drop()
  W["do-num"]()
 else:
  pass
  _drop()
  _dup()
  W["sqh"]()
  _fetch()
  _heq()
  if pop()!=0:
   pass
   _drop()
   W["do-squote"]()
  else:
   pass
   _dup()
   W["dqh"]()
   _fetch()
   _heq()
   if pop()!=0:
    pass
    _drop()
    W["do-str"]()
   else:
    pass
    _dup()
    push(I(r'''\"'''[:-1]))
    _heq()
    if pop()!=0:
     pass
     _drop()
     W["do-bslash"]()
    else:
     pass
     _dup()
     push(I(r'''("'''[:-1]))
     _heq()
     if pop()!=0:
      pass
      _drop()
      W["do-paren"]()
     else:
      pass
      _dup()
      push(I(r''':"'''[:-1]))
      _heq()
      if pop()!=0:
       pass
       _drop()
       W["do-colon"]()
      else:
       pass
       _dup()
       push(I(r''';"'''[:-1]))
       _heq()
       if pop()!=0:
        pass
        _drop()
        W["do-semi"]()
       else:
        pass
        _dup()
        push(I(r'''if"'''[:-1]))
        _heq()
        if pop()!=0:
         pass
         _drop()
         W["do-if"]()
        else:
         pass
         _dup()
         push(I(r'''else"'''[:-1]))
         _heq()
         if pop()!=0:
          pass
          _drop()
          W["do-else"]()
         else:
          pass
          _dup()
          push(I(r'''then"'''[:-1]))
          _heq()
          if pop()!=0:
           pass
           _drop()
           W["do-then"]()
          else:
           pass
           _dup()
           push(I(r'''begin"'''[:-1]))
           _heq()
           if pop()!=0:
            pass
            _drop()
            W["do-begin"]()
           else:
            pass
            _dup()
            push(I(r'''until"'''[:-1]))
            _heq()
            if pop()!=0:
             pass
             _drop()
             W["do-until"]()
            else:
             pass
             _dup()
             push(I(r'''do"'''[:-1]))
             _heq()
             if pop()!=0:
              pass
              _drop()
              W["do-do"]()
             else:
              pass
              _dup()
              push(I(r'''loop"'''[:-1]))
              _heq()
              if pop()!=0:
               pass
               _drop()
               W["do-loop"]()
              else:
               pass
               _dup()
               push(I(r'''i"'''[:-1]))
               _heq()
               if pop()!=0:
                pass
                _drop()
                W["ind"]()
                pr(r'''push(L[-1][0])"''')
                _cr()
               else:
                pass
                _dup()
                push(I(r'''variable"'''[:-1]))
                _heq()
                if pop()!=0:
                 pass
                 _drop()
                 W["do-var"]()
                else:
                 pass
                 _dup()
                 push(I(r'''@"'''[:-1]))
                 _heq()
                 if pop()!=0:
                  pass
                  _drop()
                  W["ind"]()
                  pr(r'''_fetch()"''')
                  _cr()
                 else:
                  pass
                  _dup()
                  push(I(r'''!"'''[:-1]))
                  _heq()
                  if pop()!=0:
                   pass
                   _drop()
                   W["ind"]()
                   pr(r'''_store()"''')
                   _cr()
                  else:
                   pass
                   _dup()
                   push(I(r'''."'''[:-1]))
                   _heq()
                   if pop()!=0:
                    pass
                    _drop()
                    W["ind"]()
                    pr(r'''dot()"''')
                    _cr()
                   else:
                    pass
                    _dup()
                    push(I(r'''emit"'''[:-1]))
                    _heq()
                    if pop()!=0:
                     pass
                     _drop()
                     W["ind"]()
                     pr(r'''_emit()"''')
                     _cr()
                    else:
                     pass
                     _dup()
                     push(I(r'''cr"'''[:-1]))
                     _heq()
                     if pop()!=0:
                      pass
                      _drop()
                      W["ind"]()
                      pr(r'''_cr()"''')
                      _cr()
                     else:
                      pass
                      _dup()
                      push(I(r'''+"'''[:-1]))
                      _heq()
                      if pop()!=0:
                       pass
                       _drop()
                       W["ind"]()
                       pr(r'''_add()"''')
                       _cr()
                      else:
                       pass
                       _dup()
                       push(I(r'''-"'''[:-1]))
                       _heq()
                       if pop()!=0:
                        pass
                        _drop()
                        W["ind"]()
                        pr(r'''_sub()"''')
                        _cr()
                       else:
                        pass
                        _dup()
                        push(I(r'''*"'''[:-1]))
                        _heq()
                        if pop()!=0:
                         pass
                         _drop()
                         W["ind"]()
                         pr(r'''_mul()"''')
                         _cr()
                        else:
                         pass
                         _dup()
                         push(I(r'''/"'''[:-1]))
                         _heq()
                         if pop()!=0:
                          pass
                          _drop()
                          W["ind"]()
                          pr(r'''_div()"''')
                          _cr()
                         else:
                          pass
                          _dup()
                          push(I(r'''mod"'''[:-1]))
                          _heq()
                          if pop()!=0:
                           pass
                           _drop()
                           W["ind"]()
                           pr(r'''_mod()"''')
                           _cr()
                          else:
                           pass
                           _dup()
                           push(I(r'''negate"'''[:-1]))
                           _heq()
                           if pop()!=0:
                            pass
                            _drop()
                            W["ind"]()
                            pr(r'''_neg()"''')
                            _cr()
                           else:
                            pass
                            _dup()
                            push(I(r'''="'''[:-1]))
                            _heq()
                            if pop()!=0:
                             pass
                             _drop()
                             W["ind"]()
                             pr(r'''_eq()"''')
                             _cr()
                            else:
                             pass
                             _dup()
                             push(I(r'''<"'''[:-1]))
                             _heq()
                             if pop()!=0:
                              pass
                              _drop()
                              W["ind"]()
                              pr(r'''_lt()"''')
                              _cr()
                             else:
                              pass
                              _dup()
                              push(I(r'''>"'''[:-1]))
                              _heq()
                              if pop()!=0:
                               pass
                               _drop()
                               W["ind"]()
                               pr(r'''_gt()"''')
                               _cr()
                              else:
                               pass
                               _dup()
                               push(I(r'''dup"'''[:-1]))
                               _heq()
                               if pop()!=0:
                                pass
                                _drop()
                                W["ind"]()
                                pr(r'''_dup()"''')
                                _cr()
                               else:
                                pass
                                _dup()
                                push(I(r'''drop"'''[:-1]))
                                _heq()
                                if pop()!=0:
                                 pass
                                 _drop()
                                 W["ind"]()
                                 pr(r'''_drop()"''')
                                 _cr()
                                else:
                                 pass
                                 _dup()
                                 push(I(r'''swap"'''[:-1]))
                                 _heq()
                                 if pop()!=0:
                                  pass
                                  _drop()
                                  W["ind"]()
                                  pr(r'''_swap()"''')
                                  _cr()
                                 else:
                                  pass
                                  _dup()
                                  push(I(r'''over"'''[:-1]))
                                  _heq()
                                  if pop()!=0:
                                   pass
                                   _drop()
                                   W["ind"]()
                                   pr(r'''_over()"''')
                                   _cr()
                                  else:
                                   pass
                                   _dup()
                                   push(I(r'''rot"'''[:-1]))
                                   _heq()
                                   if pop()!=0:
                                    pass
                                    _drop()
                                    W["ind"]()
                                    pr(r'''_rot()"''')
                                    _cr()
                                   else:
                                    pass
                                    _dup()
                                    push(I(r'''token"'''[:-1]))
                                    _heq()
                                    if pop()!=0:
                                     pass
                                     _drop()
                                     W["ind"]()
                                     pr(r'''_token()"''')
                                     _cr()
                                    else:
                                     pass
                                     _dup()
                                     push(I(r'''h."'''[:-1]))
                                     _heq()
                                     if pop()!=0:
                                      pass
                                      _drop()
                                      W["ind"]()
                                      pr(r'''_hdot()"''')
                                      _cr()
                                     else:
                                      pass
                                      _dup()
                                      push(I(r'''h="'''[:-1]))
                                      _heq()
                                      if pop()!=0:
                                       pass
                                       _drop()
                                       W["ind"]()
                                       pr(r'''_heq()"''')
                                       _cr()
                                      else:
                                       pass
                                       _dup()
                                       push(I(r'''h>n"'''[:-1]))
                                       _heq()
                                       if pop()!=0:
                                        pass
                                        _drop()
                                        W["ind"]()
                                        pr(r'''_h2n()"''')
                                        _cr()
                                       else:
                                        pass
                                        W["do-call"]()
W["handle"]=_f
def _f():
 pass
 W["pre"]()
 _token()
 _dup()
 push(0 )
 _eq()
 if pop()!=0:
  pass
  _drop()
 else:
  pass
  _dup()
  push(I(r'''("'''[:-1]))
  _heq()
  if pop()!=0:
   pass
   _drop()
   _token()
   W["sqh"]()
   _store()
   _token()
   W["dqh"]()
   _store()
   _token()
   _drop()
  else:
   pass
   W["handle"]()
 while True:
  pass
  _token()
  _dup()
  push(0 )
  _eq()
  if pop()!=0:
   pass
   _drop()
   push(-1 )
  else:
   pass
   W["handle"]()
   push(0 )
  if pop()!=0: break
W["main"]=_f
W["main"]()
