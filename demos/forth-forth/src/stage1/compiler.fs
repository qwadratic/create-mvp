\ stage1: Forth -> Python compiler, pure Forth, runs under stage0:
\ python3 src/stage0/stage0.py src/stage1/compiler.fs prog.fs > prog.py
\ reads prog.fs tokens via token, emits standalone Python to stdout.

variable depth
variable defname
variable ncount
variable names
variable r01 variable r02 variable r03 variable r04 variable r05 variable r06 variable r07 variable r08
variable r09 variable r10 variable r11 variable r12 variable r13 variable r14 variable r15 variable r16
variable r17 variable r18 variable r19 variable r20 variable r21 variable r22 variable r23 variable r24
variable r25 variable r26 variable r27 variable r28 variable r29 variable r30 variable r31 variable r32
variable r33 variable r34 variable r35 variable r36 variable r37 variable r38 variable r39 variable r40
variable r41 variable r42 variable r43 variable r44 variable r45 variable r46 variable r47 variable r48
variable r49 variable r50 variable r51 variable r52 variable r53 variable r54 variable r55 variable r56
variable r57 variable r58 variable r59 variable r60 variable r61 variable r62 variable r63 variable r64

: q 34 emit ;

: spaces ( n -- )
  begin dup 0 > if 32 emit 1 - 0 else -1 then until drop ;

: ind depth @ spaces ;

: depth+ depth @ 1 + depth ! ;
: depth- depth @ 1 - depth ! ;

: passln ind ." pass" cr ;

: reg-name ( h -- ) names ncount @ + ! ncount @ 1 + ncount ! ;

: is-def? ( h -- f )
  0 swap
  ncount @ 0 do dup names i + @ h= negate rot + swap loop
  drop 0 > ;

: do-num ( n -- ) ind ." push(" . ." )" cr ;

: do-colon
  token dup reg-name defname !
  ." def _f():" cr
  1 depth ! passln ;

: do-semi
  0 depth !
  ." W[" q defname @ h. q ." ]=_f" cr ;

: do-if ind ." if pop()!=0:" cr depth+ passln ;
: do-else depth- ind ." else:" cr depth+ passln ;
: do-then depth- ;
: do-begin ind ." while True:" cr depth+ passln ;
: do-until ind ." if pop()!=0: break" cr depth- ;
: do-do ind ." _do()" cr ind ." while True:" cr depth+ passln ;
: do-loop ind ." if _loop(): break" cr depth- ;

: do-var
  token dup reg-name
  ind ." W[" q h. q ." ]=_mkvar()" cr ;

: do-call ( h -- ) ind ." W[" q h. q ." ]()" cr ;

: do-str ind ." pr('''" token h. ." ''')" cr ;

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
  ." import sys" cr
  ." S=[]" cr
  ." M=[]" cr
  ." L=[]" cr
  ." W={}" cr
  ." def push(x): S.append(x)" cr
  ." def pop(): return S.pop()" cr
  ." def dot(): sys.stdout.write(str(pop())+' ')" cr
  ." def _emit(): sys.stdout.write(chr(pop()))" cr
  ." def _cr(): sys.stdout.write(chr(10))" cr
  ." def pr(s): sys.stdout.write(s[:-1])" cr
  ." def _add(): b=pop();push(pop()+b)" cr
  ." def _sub(): b=pop();push(pop()-b)" cr
  ." def _mul(): b=pop();push(pop()*b)" cr
  ." def _div(): b=pop();push(pop()//b)" cr
  ." def _mod(): b=pop();push(pop()%b)" cr
  ." def _neg(): push(-pop())" cr
  ." def _eq(): push(-1 if pop()==pop() else 0)" cr
  ." def _lt(): b=pop();push(-1 if pop()<b else 0)" cr
  ." def _gt(): b=pop();push(-1 if pop()>b else 0)" cr
  ." def _dup(): S.append(S[-1])" cr
  ." def _drop(): S.pop()" cr
  ." def _swap(): S[-2],S[-1]=S[-1],S[-2]" cr
  ." def _over(): S.append(S[-2])" cr
  ." def _rot(): S.append(S.pop(-3))" cr
  ." def _store(): a=pop();M[a]=pop()" cr
  ." def _fetch(): push(M[pop()])" cr
  ." def _do(): s=pop();l=pop();L.append([s,l])" cr
  ." def _loop():" cr
  ."  L[-1][0]+=1" cr
  ."  if L[-1][0]<L[-1][1]: return False" cr
  ."  L.pop()" cr
  ."  return True" cr
  ." def _mkvar():" cr
  ."  M.append(0)" cr
  ."  a=len(M)-1" cr
  ."  return lambda: push(a)" cr ;

: handle ( h -- )
  dup h>n if
    swap drop do-num
  else
    drop
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
    dup is-def? if do-call else drop do-str then
    then then then then then then then then then then then
    then then then then then then then then then then then
    then then then then then then then then then then
  then ;

: main
  pre
  begin
    token dup 0 = if drop -1 else handle 0 then
  until ;

main
