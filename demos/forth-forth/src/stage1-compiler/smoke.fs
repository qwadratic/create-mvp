\ smoke test for stage1 compiler ( not a pinned test )
: sq ( n -- n2 ) dup * ;
variable v
42 v !
v @ . cr
: cnt 5 begin dup . 1 - dup 0 = until drop ;
cnt cr
: tens 4 1 do i 10 * . loop ;
tens cr
: sign dup 0 < if drop ." neg" else 0 > if ." pos" else ." zero" then then ;
3 sq . cr
7 negate . cr
-5 sign cr
5 sign cr
0 sign cr
1 2 3 rot . . . cr
4 5 over . . . cr
8 9 swap . . cr
6 dup + . cr
5 3 > . 3 5 < . 5 5 = . cr
." hi" cr
65 emit 66 emit cr
17 5 mod . 17 5 / . cr
