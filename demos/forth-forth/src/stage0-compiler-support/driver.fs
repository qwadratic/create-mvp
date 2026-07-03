\ exercise compiler-support words: s" h. h= h>n token (incl. EOF + parse fail)
s" hello" h. cr
: greet s" hi" h. ;
greet ."  " greet cr
: process ( h -- )
  dup h>n if
    ." num:" . drop cr
  else
    drop
    dup s" stop" h= if
      ." eq:" h. cr
    else
      ." tok:" h. cr
    then
  then ;
: rdloop
  begin
    token dup 0 = if
      drop ." EOF" cr -1
    else
      process 0
    then
  until ;
rdloop
token 0 = . cr
