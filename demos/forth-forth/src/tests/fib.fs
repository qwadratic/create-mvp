\ first 10 fibonacci numbers on one line
: fib10  0 1 10 0 do over . swap over + loop drop drop ;
fib10 cr
