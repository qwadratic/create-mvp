#!/usr/bin/env bash
# static asserts on the self-contained UI page
set -euo pipefail
cd "$(dirname "$0")"
HTML=index.html

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$HTML" ] || fail "$HTML missing"

# no external URL references (http:// or https://)
! grep -Eq 'https?://' "$HTML" || fail "external http(s):// reference found"

# required X dark-theme colors
for hex in '#000' '#2f3336' '#e7e9ea' '#71767b' '#1d9bf0'; do
  grep -qi -- "$hex" "$HTML" || fail "missing color $hex"
done

# font
grep -q 'system-ui' "$HTML" || fail "missing system-ui font stack"

# key layout markers
for marker in 'nav-rail' 'home-header' 'compose' 'tweet-actions' \
              'search-pill' 'What&#8217;s happening' "What's happening?" \
              'Home' 'Explore' 'Notifications' 'Messages' 'Profile' \
              'Post' '600px' 'disabled'; do
  grep -qF -- "$marker" "$HTML" || fail "missing layout marker: $marker"
done

# fetch calls present
grep -q 'fetch("/api/timeline")' "$HTML" || fail "missing timeline fetch"
grep -q 'fetch("/api/tweets"' "$HTML" || fail "missing tweets POST fetch"
grep -q '"POST"' "$HTML" || fail "missing POST method"

# no animations / autofocus
! grep -Eqi 'autofocus|@keyframes|animation:' "$HTML" || fail "animation/autofocus found"

echo "OK: ui-page checks passed"
