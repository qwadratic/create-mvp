#!/bin/sh
# stage0-core check: run inline .fs snippets under stage0.py, cmp bytes.
set -u
cd "$(dirname "$0")/../.."

fail=0
tmpd=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpd"' EXIT

check() {
  # $1 = name; program on fd 3, expected bytes on stdin
  name=$1
  cat <&3 > "$tmpd/$name.fs"
  cat > "$tmpd/$name.exp"
  python3 src/stage0/stage0.py "$tmpd/$name.fs" > "$tmpd/$name.got" 2>"$tmpd/$name.err"
  if cmp -s "$tmpd/$name.got" "$tmpd/$name.exp"; then
    echo "OK: $name"
  else
    echo "FAIL: $name"
    echo "--- expected:"; od -c "$tmpd/$name.exp"
    echo "--- got:";      od -c "$tmpd/$name.got"
    cat "$tmpd/$name.err"
    fail=1
  fi
}

# arithmetic + literals (signed)
check arith 3<<'FS' <<'EOF'
1 2 + . 10 3 - . 4 5 * . 17 5 / . 17 5 mod . 7 negate . -3 . cr
FS
3 7 20 3 2 -7 -3 
EOF

# comparison: true -1, false 0
check cmpw 3<<'FS' <<'EOF'
5 5 = . 5 6 = . 3 5 < . 5 3 < . 5 3 > . 3 5 > . cr
FS
-1 0 -1 0 -1 0 
EOF

# stack ops
check stackw 3<<'FS' <<'EOF'
1 2 3 rot . . . cr
4 5 swap . . cr
6 dup + . cr
7 8 over . . . cr
9 10 drop . cr
FS
1 3 2 
4 5 
12 
7 8 7 
9 
EOF

# output: . trailing space, emit, cr, ." text"
check outw 3<<'FS' <<'EOF'
65 emit 66 emit cr ." hello world" cr 42 . cr
FS
AB
hello world
42 
EOF

# colon definitions + case-insensitivity
check colon 3<<'FS' <<'EOF'
: SQUARE DUP * ;
: cube dup square * ;
3 Square . 3 CUBE . cr
FS
9 27 
EOF

# nested if/else/then inside definition
check ifelse 3<<'FS' <<'EOF'
: cls dup 0 < if drop ." neg" else 0 = if ." zero" else ." pos" then then cr ;
-5 cls 0 cls 7 cls
FS
neg
zero
pos
EOF

# begin/until
check until 3<<'FS' <<'EOF'
: count5 0 begin dup . 1 + dup 5 = until drop cr ;
count5
FS
0 1 2 3 4 
EOF

# do/loop/i (limit start), nested loops
check doloop 3<<'FS' <<'EOF'
: tri 4 1 do 3 0 do i . loop cr loop ;
tri
: five 5 0 do i . loop cr ;
five
FS
0 1 2 
0 1 2 
0 1 2 
0 1 2 3 4 
EOF

# variable / @ / !
check vars 3<<'FS' <<'EOF'
variable x
42 x !
x @ . cr
: bump x @ 1 + x ! ;
bump bump x @ . cr
FS
42 
44 
EOF

# comments: backslash-to-EOL and inline parens (top level and in defs)
check comments 3<<'FS' <<'EOF'
\ whole line comment
1 ( inline comment ) 2 + . cr \ trailing comment
: f ( n -- n+1 ) 1 + \ add one
  ;
5 f . cr
FS
3 
6 
EOF

[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
