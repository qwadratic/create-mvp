variable a variable b variable r variable row

\ odd? ( r c -- f ) 1 iff C(r,c) odd: every base-2 digit of c <= digit of r
: odd? b ! a ! 1 r !
  begin
    b @ 2 mod  a @ 2 mod  > if 0 r ! then
    a @ 2 / a !  b @ 2 / b !
    b @ 0 =
  until r @ ;

: sier 16 0 do
    i row !
    row @ 1 + 0 do
      row @ i odd? if 42 emit else 32 emit then
    loop cr
  loop ;

sier
