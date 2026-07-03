( s" ." )

variable depth
variable defname
variable sqh
variable dqh

: q 34 emit ;
: q3 39 emit 39 emit 39 emit ;
: sp 32 emit ;

: spaces begin dup 0 > if 32 emit 1 - 0 else -1 then until drop ;
: ind depth @ spaces ;
: depth+ depth @ 1 + depth ! ;
: depth- depth @ 1 - depth ! ;
: passln ind ." pass" cr ;

: do-num ind ." push(" . ." )" cr ;

: do-colon
  token defname !
  ." def" sp ." _f():" cr
  1 depth ! passln ;

: do-semi
  0 depth !
  ." W[" q defname @ h. q ." ]=_f" cr ;

: do-if ind ." if" sp ." pop()!=0:" cr depth+ passln ;
: do-else depth- ind ." else:" cr depth+ passln ;
: do-then depth- ;
: do-begin ind ." while" sp ." True:" cr depth+ passln ;
: do-until ind ." if" sp ." pop()!=0:" sp ." break" cr depth- ;
: do-do ind ." _do()" cr ind ." while" sp ." True:" cr depth+ passln ;
: do-loop ind ." if" sp ." _loop():" sp ." break" cr depth- ;

: do-var
  token
  ind ." W[" q h. q ." ]=_mkvar()" cr ;

: do-call ind ." W[" q h. q ." ]()" cr ;

: do-str ind ." pr(r" q3 token h. q3 ." )" cr ;
: do-squote ind ." push(I(r" q3 token h. q3 ." [:-1]))" cr ;

: do-bslash
  begin
    token dup 0 = if drop -1 else
      dup s" :" h= if drop do-colon -1 else drop 0 then
    then
  until ;

: do-paren
  begin
    token dup 0 = if drop -1 else
      s" )" h= if -1 else 0 then
    then
  until ;

: pre
  ." import" sp ." sys" cr
  ." S=[]" cr
  ." M=[]" cr
  ." L=[]" cr
  ." W={}" cr
  ." ST=['']" cr
  ." IT=[]" cr
  ." def" sp ." push(x):" sp ." S.append(x)" cr
  ." def" sp ." pop():" sp ." return" sp ." S.pop()" cr
  ." def" sp ." dot():" sp ." sys.stdout.write(str(pop())+chr(32))" cr
  ." def" sp ." _emit():" sp ." sys.stdout.write(chr(pop()))" cr
  ." def" sp ." _cr():" sp ." sys.stdout.write(chr(10))" cr
  ." def" sp ." pr(s):" sp ." sys.stdout.write(s[:-1])" cr
  ." def" sp ." I(s):" cr
  sp ." ST.append(s)" cr
  sp ." return" sp ." len(ST)-1" cr
  ." def" sp ." _token():" cr
  sp ." if" sp ." not" sp ." IT:" cr
  sp sp ." IT.append(iter(open(sys.argv[1]).read().split()))" cr
  sp ." for" sp ." t" sp ." in" sp ." IT[0]:" cr
  sp sp ." push(I(t))" cr
  sp sp ." return" cr
  sp ." push(0)" cr
  ." def" sp ." _hdot():" sp ." sys.stdout.write(ST[pop()])" cr
  ." def" sp ." _heq():" sp ." b=pop();push(-1" sp ." if" sp ." ST[pop()]==ST[b]" sp ." else" sp ." 0)" cr
  ." def" sp ." _h2n():" cr
  sp ." try:" cr
  sp sp ." push(int(ST[pop()],10))" cr
  sp sp ." push(-1)" cr
  sp ." except:" cr
  sp sp ." push(0)" cr
  sp sp ." push(0)" cr
  ." def" sp ." _add():" sp ." b=pop();push(pop()+b)" cr
  ." def" sp ." _sub():" sp ." b=pop();push(pop()-b)" cr
  ." def" sp ." _mul():" sp ." b=pop();push(pop()*b)" cr
  ." def" sp ." _div():" sp ." b=pop();push(pop()//b)" cr
  ." def" sp ." _mod():" sp ." b=pop();push(pop()%b)" cr
  ." def" sp ." _neg():" sp ." push(-pop())" cr
  ." def" sp ." _eq():" sp ." push(-1" sp ." if" sp ." pop()==pop()" sp ." else" sp ." 0)" cr
  ." def" sp ." _lt():" sp ." b=pop();push(-1" sp ." if" sp ." pop()<b" sp ." else" sp ." 0)" cr
  ." def" sp ." _gt():" sp ." b=pop();push(-1" sp ." if" sp ." pop()>b" sp ." else" sp ." 0)" cr
  ." def" sp ." _dup():" sp ." S.append(S[-1])" cr
  ." def" sp ." _drop():" sp ." S.pop()" cr
  ." def" sp ." _swap():" sp ." S[-2],S[-1]=S[-1],S[-2]" cr
  ." def" sp ." _over():" sp ." S.append(S[-2])" cr
  ." def" sp ." _rot():" sp ." S.append(S.pop(-3))" cr
  ." def" sp ." _store():" sp ." a=pop();M[a]=pop()" cr
  ." def" sp ." _fetch():" sp ." push(M[pop()])" cr
  ." def" sp ." _do():" sp ." s=pop();l=pop();L.append([s,l])" cr
  ." def" sp ." _loop():" cr
  sp ." L[-1][0]+=1" cr
  sp ." if" sp ." L[-1][0]<L[-1][1]:" sp ." return" sp ." False" cr
  sp ." L.pop()" cr
  sp ." return" sp ." True" cr
  ." def" sp ." _mkvar():" cr
  sp ." M.append(0)" cr
  sp ." a=len(M)-1" cr
  sp ." return" sp ." lambda:" sp ." push(a)" cr ;

: handle
  dup h>n if
    swap drop do-num
  else
    drop
    dup sqh @ h= if drop do-squote else
    dup dqh @ h= if drop do-str else
    dup s" \" h= if drop do-bslash else
    dup s" (" h= if drop do-paren else
    dup s" :" h= if drop do-colon else
    dup s" ;" h= if drop do-semi else
    dup s" if" h= if drop do-if else
    dup s" else" h= if drop do-else else
    dup s" then" h= if drop do-then else
    dup s" begin" h= if drop do-begin else
    dup s" until" h= if drop do-until else
    dup s" do" h= if drop do-do else
    dup s" loop" h= if drop do-loop else
    dup s" i" h= if drop ind ." push(L[-1][0])" cr else
    dup s" variable" h= if drop do-var else
    dup s" @" h= if drop ind ." _fetch()" cr else
    dup s" !" h= if drop ind ." _store()" cr else
    dup s" ." h= if drop ind ." dot()" cr else
    dup s" emit" h= if drop ind ." _emit()" cr else
    dup s" cr" h= if drop ind ." _cr()" cr else
    dup s" +" h= if drop ind ." _add()" cr else
    dup s" -" h= if drop ind ." _sub()" cr else
    dup s" *" h= if drop ind ." _mul()" cr else
    dup s" /" h= if drop ind ." _div()" cr else
    dup s" mod" h= if drop ind ." _mod()" cr else
    dup s" negate" h= if drop ind ." _neg()" cr else
    dup s" =" h= if drop ind ." _eq()" cr else
    dup s" <" h= if drop ind ." _lt()" cr else
    dup s" >" h= if drop ind ." _gt()" cr else
    dup s" dup" h= if drop ind ." _dup()" cr else
    dup s" drop" h= if drop ind ." _drop()" cr else
    dup s" swap" h= if drop ind ." _swap()" cr else
    dup s" over" h= if drop ind ." _over()" cr else
    dup s" rot" h= if drop ind ." _rot()" cr else
    dup s" token" h= if drop ind ." _token()" cr else
    dup s" h." h= if drop ind ." _hdot()" cr else
    dup s" h=" h= if drop ind ." _heq()" cr else
    dup s" h>n" h= if drop ind ." _h2n()" cr else
    do-call
    then then then then then then then then then then
    then then then then then then then then then then
    then then then then then then then then then then
    then then then then then then then then
  then ;

: main
  pre
  token dup 0 = if drop else
    dup s" (" h= if drop token sqh ! token dqh ! token drop else
    handle then
  then
  begin token dup 0 = if drop -1 else handle 0 then until ;

main
