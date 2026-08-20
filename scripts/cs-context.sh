#!/usr/bin/env bash
# cs-context.sh — MEASURE a session's context usage instead of believing a
# self-report about it.
#
#   usage: bash scripts/cs-context.sh                 # every registered session
#          bash scripts/cs-context.sh bob_2026-08-20  # one side, by its prefix
#          bash scripts/cs-context.sh /path/to.jsonl  # an explicit transcript
#
# ⛔⛔ WHY THIS EXISTS. For about a week, paired sessions here repeatedly
# announced "my context is very deep now" and stopped work — including
# overnight runs that were supposed to continue. When someone finally opened
# both context windows, one session was at 52% and the other at 37%.
# ⇒ THE CLAIM WAS FALSE EVERY TIME AND NOBODY HAD EVER CHECKED IT. The number
# was sitting on disk in each session's own transcript throughout.
#
# ⭐ THE RULE IT ENFORCES: a session's statement about its OWN state is a
# REPORT, not a measurement — the same class as an instrument answering a
# question about itself. Measure it, quote the number, then decide.
#
# HOW IT WORKS: every assistant turn is appended to the session's transcript
# .jsonl with a `usage` block. The LAST one describes the request just made, so
#   input_tokens + cache_creation_input_tokens + cache_read_input_tokens
# is what was actually sent — i.e. the live context size.
# ⚠️ It is the size at the last COMPLETED turn, so a session mid-turn reads
# slightly low. That is a FLOOR, which is the safe direction for a "should we
# stop?" decision.
#
# ⛔ The transcript path comes from cs-register.sh, which is why registering at
# session start matters beyond the watchdog.
#
# ⚠️ CONTEXT_WINDOW defaults to 1,000,000. Set it to your model's real window.
set -u

DIR="${CS_DIR:-.claude/cross-session}"
WINDOW="${CONTEXT_WINDOW:-1000000}"

resolve() {                      # /c/x -> C:/x  (Git Bash path -> Windows path)
  printf '%s' "$1" | sed -E 's#^/([a-zA-Z])/#\U\1:/#'
}

report() {
  local label="$1" path="$2"
  local win; win="$(resolve "$path")"
  if [ ! -f "$win" ] && [ ! -f "$path" ]; then
    printf '%-22s TRANSCRIPT NOT FOUND: %s\n' "$label" "$path" >&2
    return 1
  fi
  [ -f "$win" ] || win="$path"
  WIN="$win" WINDOW="$WINDOW" LABEL="$label" python -c '
import json, os
p = os.environ["WIN"]; window = int(os.environ["WINDOW"]); label = os.environ["LABEL"]
last = None; turns = 0
with open(p, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        try: o = json.loads(line)
        except Exception: continue
        u = (o.get("message") or {}).get("usage") or o.get("usage")
        if isinstance(u, dict) and ("input_tokens" in u or "cache_read_input_tokens" in u):
            last = u; turns += 1
if last is None:
    print("%-22s no usage block yet" % label); raise SystemExit(0)
tot = sum(int(last.get(k, 0) or 0) for k in
          ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
pct  = 100.0 * tot / window
free = window - tot
# The verdict is measured against a RESERVE, not against a percentage.
# ⛔ An earlier version banded this at 60/80/90%. Those numbers were INVENTED —
#    nothing changes at 60%, and a percentage cannot answer the only question
#    that matters: is there room for the work left plus a handoff?
# ✅ RESERVE = what a handoff actually costs, from the two most recent real ones:
#    38,654 and 30,616 bytes written (~9.7k and ~7.7k tokens of output), plus
#    re-reading them, the ledger and page updates, and the completeness sweep.
#    HANDOFF_RESERVE below is that, rounded up generously. Override it if a
#    future handoff measures larger.
reserve = int(os.environ.get("HANDOFF_RESERVE", "100000"))
if free > reserve * 3:
    verdict = "PLENTY - room for the work AND a handoff. A stop on context grounds is NOT justified."
elif free > reserve:
    verdict = "ROOM FOR ONE MORE ITEM - then hand off. Not a reason to stop now."
else:
    verdict = "HAND OFF NOW - free space is at or below the reserve a handoff needs."
print("%-22s %s / %s  (%.1f%%)  free %s  turns %d" %
      (label, format(tot, ","), format(window, ","), pct, format(free, ","), turns))
print("%-22s %s" % ("", verdict))
print("%-22s (handoff reserve %s - measured from the last two real handoffs, not assumed)" %
      ("", format(reserve, ",")))
'
}

if [ $# -ge 1 ] && [ -f "$(resolve "$1")" ]; then
  report "transcript" "$1"; exit $?
fi

if [ $# -ge 1 ]; then
  f="$DIR/.$1.transcript"
  [ -f "$f" ] || { echo "no registered transcript for '$1' (looked in $f)" >&2; exit 1; }
  report "$1" "$(cat "$f")"; exit $?
fi

found=0
for f in "$DIR"/.*.transcript; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"; base="${base#.}"; base="${base%.transcript}"
  report "$base" "$(cat "$f")" && found=1
done
[ "$found" = 1 ] || { echo "no registered transcripts in $DIR" >&2; exit 1; }
