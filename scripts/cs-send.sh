#!/usr/bin/env bash
# cs-send.sh — write one message file for the partner session.
#
#   usage:  cs-send.sh <your_role> < body.md
#           echo "text" | cs-send.sh alice
#           cs-send.sh alice <<'EOF'
#           multi-line body
#           EOF
#
# Roles are whatever you choose — "alice"/"bob", "lead"/"worker", "advisor"/"impl".
# Both sessions must agree on the two names and nothing else.
#
# Numbering is 4-digit and monotonic per role, so the two sides never collide.
#
# ⛔ THE WRITE IS ATOMIC (.tmp then rename) AND THAT IS NOT OPTIONAL. Without it the
# partner's watcher can observe a half-written file and act on a truncated instruction.
# A rename is atomic on the same filesystem; a plain redirect is not.
set -u

DIR="${CS_DIR:-.claude/cross-session}"
ROLE="${1:?your role name required, e.g. alice}"
mkdir -p "$DIR"

# ⛔⛔ THE COUNTER IS PERSISTED IN A DOTFILE, NOT DERIVED FROM THE LISTING ALONE.
# If you derive it only from the files present, then CLEARING the message folder resets
# numbering to 0001 and RECYCLES filenames. A recycled name that is still in a running
# watcher's seen-set produces no diff, and the watcher reconciles its state anyway — so the
# message is SWALLOWED, silently, with no error anywhere. Not delayed. Gone.
# ⭐ Clearing is a normal, recommended housekeeping step, which is what makes this dangerous:
# the routine maintenance degrades the transport, and nothing in either script says so.
# ✅ Dotfiles survive `rm *.md`. Taking the MAX of counter and listing is correct whether or
# not the counter exists, so this is safe to drop into an existing folder with no migration.
SEQ="$DIR/.${ROLE}.seq"
listed=$(ls -1 "$DIR"/${ROLE}_*.md 2>/dev/null \
        | sed -E "s|.*/${ROLE}_([0-9]{4})\.md$|\1|" \
        | grep -E '^[0-9]{4}$' | sort -n | tail -1)
stored=$(grep -E '^[0-9]+$' "$SEQ" 2>/dev/null | tail -1)
a=$(( 10#${listed:-0} )); b=$(( 10#${stored:-0} ))
last=$a; [ "$b" -gt "$a" ] && last=$b
next=$(printf "%04d" $(( last + 1 )))
printf '%s\n' "$(( last + 1 ))" > "$SEQ"

f="$DIR/${ROLE}_${next}.md"
tmp="$f.tmp"

# ⛔⛔ THERE IS DELIBERATELY NO "does the heading number match the filename" CHECK.
# One existed and was removed: it scanned the first lines for a 4-digit run, which cannot
# tell a number the message CLAIMS from a number it merely MENTIONS. It fired on a reply
# that cited the message it was answering — and quoting the number you are replying to is
# the most natural thing anyone writes, so THE MOST COMMON LEGITIMATE SHAPE WAS THE ONE IT
# TRIPPED ON.
# ⚠️ A warning that cries wolf on ordinary prose does not merely waste a glance: it spends
# the credibility that is the only thing making the warning work, and then the real case is
# ignored along with it.
# ⭐ A STRING MATCH CANNOT DISTINGUISH USE FROM MENTION. Do not reintroduce this as a
# cleverer regex — the flaw is in the category, not the pattern.
# ✅ Instead the mismatch is PREVENTED: THE FILENAME IS AUTHORITATIVE, and CS_HEADER=1 makes
# the script write the heading itself so there is no hand-typed number to disagree.
if [ "${CS_HEADER:-0}" = "1" ]; then
  { printf '# %s %s\n\n' "$ROLE" "$next"; cat; } > "$tmp"
else
  cat > "$tmp"
fi

mv "$tmp" "$f"
echo "$f"
