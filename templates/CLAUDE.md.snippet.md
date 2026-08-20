# Paste into your CLAUDE.md

Replace `ROLE_A` and `ROLE_B` with your two chosen role names. Keep both variants — each
session reads the same file and needs to find its own line.

⛔ **This belongs in `CLAUDE.md`, not in a starter prompt.** The watcher is session-only and
dies silently, so the arming ritual has to live in the file every session reads at startup. A
rule that lives in a chat message dies at the next handoff.

---

#### ⛔⛔ CROSS-SESSION MESSAGING — ARM IT AT SESSION START ####

**Messages between the two sessions go through a FILE BUS, not the built-in channel.**
Every line the watcher prints becomes a notification that wakes this session, including when
it is idle.

✅ **RUN THESE AT THE START OF EVERY SESSION.** Pick your own unique marker string.

If you are **ROLE_A**:
```bash
bash scripts/cs-register.sh ROLE_A_<pair-stamp> selfid-<anything-unique>
# then arm the watcher with the Monitor tool, persistent:true:
bash scripts/cs-watch.sh ROLE_B_<pair-stamp>
# to send:
echo "..." | bash scripts/cs-send.sh ROLE_A_<pair-stamp>
```

If you are **ROLE_B**, swap every `ROLE_A` ⇄ `ROLE_B` above.

⛔⛔ **GIVE EVERY PAIR ITS OWN `<pair-stamp>` AND NEVER REUSE ONE.** The bus addresses by
PREFIX, and nothing in the design claims exclusivity — **a second pair started in this
directory with the same role names silently joins the first pair's conversation.** One
dispatch then reaches two live workers, both do the right thing, and they race on the same
files. Use the same stamp you put in the session titles.

⛔ **THE BUS IS A PATH, NOT A NAME — always run these from the same directory.** The scripts
resolve `.claude/cross-session/` relative to the working directory, so a send from elsewhere
lands in a different bus and nothing reports it.

⛔ **THE MARKER MUST BE TYPED INTO THE COMMAND LINE.** Only the invoking command reaches the
transcript, so a marker generated inside the script is invisible and registration fails.

⛔ **THE WATCHER IS SESSION-ONLY — it dies with the session and NOTHING says so.**

⚠️ **On a RE-ARM the whole inbox is replayed. That is NOT new mail** — check the highest
number you have already answered before actioning any of it.

✅ **DECLARING A TERMINAL STATE: `touch .claude/cross-session/.quiet`.** When a session is
supposed to be silent — work finished, waiting on the human — say so. No watchdog can tell
that from a stall, and each alert costs a full model turn. **Any new message from either side
clears the flag automatically**, so it cannot be left on and mask a real stall.

⛔⛔ **AND THE ORDER IS LOAD-BEARING: SET THE FLAG AS YOUR FINAL ACT AND SEND NOTHING AFTER
IT.** *"Touch `.quiet` and tell your partner you have"* is **self-defeating** — the watcher
clears the flag on every incoming message, so **the confirming message is what deletes the
thing it reports.** Measured: the flag was set, verified by `ls`, and gone one second later
because the acknowledgement arrived. Both observations were true and neither described the
state that existed next.
⚠️ The auto-clear is CORRECT and must not be "fixed" — it is what stops a stale flag
masking a real stall. **`.quiet` can only ever be set by an act followed by nothing.**

⛔ **DO NOT ADD A SCHEDULED JOB TO CHECK THE WATCHER IS ALIVE.** It costs a full turn every
fire — ~48 a day at 30-minute intervals, each re-sending this entire file — and it guards a
failure **the PARTNER's watchdog already detects**: a session whose watcher died stops being
woken, its transcript stops moving, and the partner reports it INACTIVE.

⚠️ **NEVER PUT A LITERAL ON A COMMAND LINE THAT YOUR OWN PERMISSION HOOKS GUARD.** If you
have a `PreToolUse` hook that greps command text for dangerous patterns, it cannot tell why
the string is there — a read-only search, a heredoc or a note to your partner all trip it.
Search with the `Grep` tool instead (hooks usually match only `Bash`/`PowerShell`), or put the
terms in a file and use `grep -f`.
