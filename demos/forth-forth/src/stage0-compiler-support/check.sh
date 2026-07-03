#!/bin/sh
# check: stage0 compiler-support words (token/h./h=/h>n/s") byte-exact
set -e
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

printf 'hello\nhi hi\ntok:foo\nnum:42 \nnum:-7 \neq:stop\ntok:12x\ntok:bar\nEOF\n-1 \n' > "$tmp/expected"
python3 src/stage0/stage0.py src/stage0-compiler-support/driver.fs src/stage0-compiler-support/input.fs > "$tmp/got"
cmp "$tmp/expected" "$tmp/got"

# token with no input file at all -> immediate EOF (0)
printf 'token 0 = . cr\n' > "$tmp/noinput.fs"
printf -- '-1 \n' > "$tmp/expected2"
python3 src/stage0/stage0.py "$tmp/noinput.fs" > "$tmp/got2"
cmp "$tmp/expected2" "$tmp/got2"

echo OK
