#!/usr/bin/env bash
# cs-selftest.sh — verify the bus works on THIS machine before you rely on it.
#
#   usage:  bash scripts/cs-selftest.sh
#
# It runs entirely in a temp directory and touches nothing else. It does NOT test the
# Monitor-tool wake — that can only be observed from inside Claude Code — but it does test
# everything the wake depends on: numbering, atomicity, detection, and inline body output.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CS_DIR="$WORK/msgs"
export CS_POLL=1

pass=0; fail=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }

echo "cs-selftest — working in $WORK"
echo

# --- 1. numbering, per role, 4 digits -------------------------------------
echo "one"   | bash "$HERE/cs-send.sh" alice >/dev/null
echo "two"   | bash "$HERE/cs-send.sh" alice >/dev/null
echo "other" | bash "$HERE/cs-send.sh" bob   >/dev/null
[ -f "$CS_DIR/alice_0001.md" ] && [ -f "$CS_DIR/alice_0002.md" ] \
  && ok "numbering increments and zero-pads to 4" || bad "numbering"
[ -f "$CS_DIR/bob_0001.md" ] \
  && ok "each role has its own counter (no collision)" || bad "per-role counters"

# --- 2. atomicity leaves no debris ----------------------------------------
if [ "$(ls -1 "$CS_DIR"/*.tmp 2>/dev/null | wc -l | tr -d ' ')" = "0" ]; then
  ok "atomic write left no .tmp files"
else
  bad "atomic write left .tmp debris"
fi

# --- 3. a MENTIONED number must not be mistaken for a CLAIMED one ---------
# The regression this guards: a heading check that scans for a 4-digit run fires on a reply
# quoting the message it answers — the most common legitimate shape there is.
warn=$(printf 'replying to your 0002 about the parser\nmore body\n' | bash "$HERE/cs-send.sh" alice 2>&1 >/dev/null)
if [ -z "$warn" ]; then
  ok "a number the message MENTIONS produces no spurious warning"
else
  bad "spurious warning on a mentioned number: $warn"
fi

# --- 3b. CS_HEADER prevents the mismatch instead of detecting it ----------
hf=$(printf 'body only, no heading\n' | CS_HEADER=1 bash "$HERE/cs-send.sh" bob)
hnum=$(basename "$hf" .md | sed -E 's/.*_([0-9]{4})$/\1/')
if head -1 "$hf" | grep -q "bob ${hnum}"; then
  ok "CS_HEADER=1 writes a heading that cannot disagree with the filename"
else
  bad "CS_HEADER did not write a matching heading (first line: $(head -1 "$hf"))"
fi

# --- 4. the watcher detects a new file and prints the BODY inline ---------
LOG="$WORK/watch.log"
bash "$HERE/cs-watch.sh" bob > "$LOG" 2>&1 &
WPID=$!
sleep 3
printf 'SENTINEL-LINE-ALPHA\nSENTINEL-LINE-BETA\n' | bash "$HERE/cs-send.sh" bob >/dev/null
sleep 4
kill "$WPID" 2>/dev/null; wait "$WPID" 2>/dev/null

grep -q "WATCHER ARMED" "$LOG" && ok "watcher prints an arming line" || bad "no arming line"
grep -q "NEW MESSAGE" "$LOG"   && ok "watcher detects a new file"    || bad "new file not detected"
if grep -q "SENTINEL-LINE-ALPHA" "$LOG" && grep -q "SENTINEL-LINE-BETA" "$LOG"; then
  ok "message BODY is printed inline (no follow-up read needed)"
else
  bad "body was not printed inline"
fi

# --- 5. the .quiet flag suppresses the watchdog ---------------------------
grep -q '\[ -f "\$DIR/.quiet" \] && continue' "$HERE/cs-watch.sh" \
  && ok ".quiet suppression is present in the watcher" || bad ".quiet suppression missing"

# --- 6. CLEARING THE FOLDER MUST NOT RECYCLE FILENAMES --------------------
# The regression this guards: numbering derived only from the listing resets to 0001 after a
# clear, recycled names produce no diff in a running watcher, and the message is SWALLOWED
# with no error. Clearing is normal housekeeping, which is exactly what makes it dangerous.
before=$(ls -1 "$CS_DIR"/alice_*.md 2>/dev/null | wc -l | tr -d ' ')
rm -f "$CS_DIR"/*.md
after_clear=$(printf 'post-clear\n' | bash "$HERE/cs-send.sh" alice)
case "$(basename "$after_clear")" in
  alice_0001.md) bad "clearing RESET the counter — filenames recycle and messages can be swallowed" ;;
  *)             ok  "counter survives a clear (got $(basename "$after_clear") after $before files)" ;;
esac

# --- 7. CONTROL — the harness can actually FAIL ---------------------------
# Without this, a run of all-PASS proves nothing: a broken test file also prints no failures.
if grep -q "THIS-STRING-IS-DELIBERATELY-ABSENT" "$LOG"; then
  bad "CONTROL: found a string that cannot exist — the checks are not trustworthy"
else
  ok "CONTROL: a known-absent string is correctly NOT found"
fi

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
