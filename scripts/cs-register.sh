#!/usr/bin/env bash
# cs-register.sh — record THIS session's transcript path so the partner's watchdog can tell
# "stuck" from "working but not reporting".
#
#   usage:  cs-register.sh <your_role> <unique_marker>
#           cs-register.sh alice selfid-a7f3c1
#
# OPTIONAL. The message bus works without it; only the watchdog legs need it.
#
# ⛔⛔ HOW IT IDENTIFIES ITSELF, AND WHY IT TAKES A MARKER ARGUMENT.
# A session is not told its own transcript id. What IS recorded in the transcript is the
# COMMAND LINE of each tool call — so the marker must be typed into the command by the
# caller. This script then finds which .jsonl contains it. That file is this session's own.
#
# ⛔ A MARKER GENERATED INSIDE THIS SCRIPT DOES NOT WORK. It never appears in the transcript,
# because only the invoking command line is recorded, not the script's internals. That was
# tried first and failed silently.
#
# ⛔ AND DO NOT SUBSTITUTE "the most recently modified transcript". With two sessions running
# in one project the partner's file is frequently the newest, so that heuristic returns the
# WRONG file exactly when both sessions are active — which is the only time this matters.
set -u

DIR="${CS_DIR:-.claude/cross-session}"
ROLE="${1:?your role name required, e.g. alice}"
MARKER="${2:?unique marker required — it must appear in THIS command line}"
PROJ_ROOT="${CS_PROJECTS_DIR:-$HOME/.claude/projects}"

mkdir -p "$DIR"

hit=""
for _ in 1 2 3 4 5; do
  sleep 2
  hit=$(grep -rl -- "$MARKER" "$PROJ_ROOT"/*/*.jsonl 2>/dev/null | head -1)
  [ -n "$hit" ] && break
done

if [ -z "$hit" ]; then
  echo "REGISTER FAILED: no transcript under $PROJ_ROOT contains marker '$MARKER'." >&2
  echo "The message bus still works; only the watchdog legs are disabled." >&2
  echo "If your transcripts live elsewhere, set CS_PROJECTS_DIR and retry." >&2
  exit 1
fi

printf '%s\n' "$hit" > "$DIR/.${ROLE}.transcript"
echo "registered ${ROLE} -> $(basename "$hit")"
