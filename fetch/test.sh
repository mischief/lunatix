#!/bin/sh
# SPDX-License-Identifier: ISC
# fetch against a server on loopback, so the test needs no network.
D="$(cd "$(dirname "$0")" && pwd)"
command -v python3 >/dev/null 2>&1 || exit 77

. "$(dirname "$0")/../testenv.sh"
FETCH="lua5.4 $D/fetch.lua"
TMP=$(mktemp -d)
SERVER=
cleanup() {
	if [ -n "$SERVER" ]; then
		kill "$SERVER" 2>/dev/null
		wait "$SERVER" 2>/dev/null
	fi
	rm -rf "$TMP"
}
trap cleanup EXIT

mkdir "$TMP/www"
printf 'hello over http\n' > "$TMP/www/hello.txt"
dd if=/dev/urandom of="$TMP/www/blob.bin" bs=1000 count=50 2>/dev/null

# port 0 lets the kernel pick, which is what keeps two runs of this test
# from landing on the same one; the server says which it got
# exec, or $! is the subshell and not the server: a subshell holding
# more than one command is not replaced by what it runs, so killing $!
# leaves the server behind for init to adopt
(cd "$TMP/www" && exec python3 -u -m http.server 0 --bind 127.0.0.1 > "$TMP/log" 2>&1) &
SERVER=$!
PORT=
n=0
while [ -z "$PORT" ]; do
	PORT=$(sed -n 's/.*port \([0-9]*\).*/\1/p' "$TMP/log" 2>/dev/null | head -1)
	n=$((n + 1))
	[ "$n" -gt 50 ] && exit 1
	[ -z "$PORT" ] && sleep 0.1
done
n=0
while ! $FETCH "http://127.0.0.1:$PORT/hello.txt" >/dev/null 2>&1; do
	n=$((n + 1))
	[ "$n" -gt 50 ] && exit 1
	sleep 0.1
done

# a small body, and a big one that arrives in several reads
$FETCH "http://127.0.0.1:$PORT/hello.txt" > "$TMP/got.txt" || exit 1
cmp -s "$TMP/got.txt" "$TMP/www/hello.txt" || exit 1
$FETCH "http://127.0.0.1:$PORT/blob.bin" > "$TMP/got.bin" || exit 1
cmp -s "$TMP/got.bin" "$TMP/www/blob.bin" || exit 1

# -i prints the status line ahead of the body
$FETCH -i "http://127.0.0.1:$PORT/hello.txt" | head -1 | grep -q "^HTTP 200" || exit 1

# -O names the file after the url
(cd "$TMP" && $FETCH -qO "http://127.0.0.1:$PORT/hello.txt") || exit 1
cmp -s "$TMP/hello.txt" "$TMP/www/hello.txt" || exit 1

# a missing page is an error, and https says why it cannot
$FETCH "http://127.0.0.1:$PORT/nope" >/dev/null 2>&1 && exit 1
$FETCH "https://example.com/" >/dev/null 2>&1 && exit 1
exit 0
