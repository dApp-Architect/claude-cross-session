# claude-cross-session

**A file-based message bus that lets two Claude Code sessions talk to each other — including waking a session that is sitting idle.**

Five small shell scripts — two for the bus itself, three for the watchdog, context measurement and self-test. No daemon, no server, no dependencies beyond `bash` and coreutils.

---

## Why this exists

If you run two Claude Code sessions as a pair — one implementing, one reviewing, or any split you like — they need to talk. The built-in cross-session messaging can stop delivering, and when it does it fails in the worst possible way: **the send reports success and the message is never processed.** The sender plans around "delivered", the receiver knows nothing, and nobody is told to retry.

This replaces it with something you can see on disk.

It is also worth using even when the built-in channel works, because a file has properties a message queue does not:

| | built-in messaging | this |
|---|---|---|
| Survives an app restart | no | **yes** |
| Second message overwrites the first | **yes, silently** | no |
| Interrupting the receiver discards the message | **yes** | no |
| Delivery depends on whether the receiver is busy | **yes** | no |
| Auditable afterwards | no | **yes — it is a folder** |

---

## How it works

Each session runs a small polling loop under Claude Code's `Monitor` tool. When a message file appears, the loop prints it, and **every line printed becomes a notification that wakes the session — even an idle one.** That wake is the entire mechanism.

**The polling happens in the shell, not in the model.** An empty poll prints nothing and costs zero tokens. A model turn happens only when a message actually arrives. This is why a 2-second poll is affordable, and why a *scheduled prompt* that checks for messages is not — that costs a full turn every time it fires, usually to find nothing.

The message body is printed **inline**, so it arrives inside the notification and the receiving session needs no follow-up file read.

---

## Install

Copy `scripts/` into your project and make them executable:

```bash
cp -r scripts/ your-project/scripts/
chmod +x your-project/scripts/cs-*.sh
```

Add the message folder to `.gitignore` — the messages are chatter, not source:

```
.claude/cross-session/
```

Keep the scripts tracked. If they are untracked, a `git stash` or a fresh clone silently removes the thing your instructions tell every new session to run.

---

## Usage

Pick two role names. Anything you like — `alice`/`bob`, `lead`/`worker`, `advisor`/`impl`. Both sessions must agree on the two names and nothing else.

**In session A**, arm the watcher with the `Monitor` tool, `persistent: true`:

```bash
bash scripts/cs-watch.sh bob
```

**In session B:**

```bash
bash scripts/cs-watch.sh alice
```

**To send**, from either side:

```bash
echo "found the bug in the parser, fixing now" | bash scripts/cs-send.sh alice
```

That is the whole system. Messages land in `.claude/cross-session/alice_0001.md`, numbered per role so the two sides never collide.

### ⛔⛔ Give every pair its own channel names — this one is a safety bug, not a nicety

**The bus addresses by PREFIX, and nothing in the design claims exclusivity.** If you start a
second pair in the same directory using the same role names, **it silently joins the first
pair's conversation.** There is no error and no warning: one dispatch reaches two live
workers, both of them do the right thing, and they race each other on the same files.

This is not hypothetical. It cost a fresh pair its first hour, and one of the two workers came
a single anchor-match away from deleting a guard on a money path.

✅ **The fix needs no code.** The prefix is a plain argument to every script, so stamp it:

```bash
bash scripts/cs-register.sh alice_2026-08-20_1333 selfid-a-whatever
bash scripts/cs-watch.sh    bob_2026-08-20_1333
echo "..." | bash scripts/cs-send.sh alice_2026-08-20_1333
```

Use the same stamp you put in the session titles, so a window and its channel can be matched
by eye. **Never reuse a stamp.**

### ⛔ The bus is a PATH, not a name

The scripts resolve `.claude/cross-session/` **relative to the working directory**. A send
from a different directory writes to a different bus, the partner never sees it, and nothing
reports the mismatch. **Always run them from the same directory** — in practice, your
project root.

### Optional: the watchdog

`cs-register.sh` records a session's transcript path so the *partner's* watcher can tell "stuck" from "working but not reporting":

```bash
bash scripts/cs-register.sh alice selfid-pick-something-unique
```

⛔ **The marker must be typed on the command line.** Only the invoking command is recorded in the transcript, so a marker the script generates internally is invisible and registration fails.

With both sides registered, the watcher adds two alerts:

- **partner INACTIVE** — no transcript activity for 15 minutes. Stuck, blocked, or waiting.
- **partner ACTIVE but not reporting** — working for 25 minutes without sending anything. Diverged, or forgot.

### Measuring context, instead of believing a claim about it

```bash
bash scripts/cs-context.sh            # every registered session
bash scripts/cs-context.sh bob_2026-08-20_1333   # one side
```

⛔⛔ **Do not stop work because a session says its context is nearly full — measure it.**
For about a week, paired sessions here announced *"my context is very deep now"* and ended
runs that were meant to continue overnight. When someone finally opened both windows, one
session was at **52%** and the other at **37%**. The claim was false every time, and the real
number had been on disk the whole time, in each session's own transcript.

⭐ **A session's statement about its own state is a REPORT, not a measurement** — the same
class as an instrument answering a question about itself. This reads the `usage` block of the
last completed turn, so it is a floor: a session mid-turn reads slightly low, which is the
safe direction for a "should we stop?" decision.

⚠️ **The verdict is measured against a RESERVE, not a percentage.** An earlier version banded
it at 60/80/90% — numbers that were simply invented, inside the very tool built to stop
unmeasured numbers. They survived because they *sounded* like thresholds. `HANDOFF_RESERVE`
is instead sized from what real handoffs actually cost; raise it if yours measure larger.
Set `CONTEXT_WINDOW` to your model's real window.

⛔ It reads the transcript paths written by `cs-register.sh`, so registering at session start
matters beyond the watchdog.

---

### Declaring a quiet period

When a session is *supposed* to be silent — work finished, waiting on a human — say so:

```bash
touch .claude/cross-session/.quiet
```

No watchdog can distinguish "silent because instructed" from "silent because stuck", so write the state down instead of inferring it. **Any new message from either side clears the flag automatically**, so it cannot be left on and mask a real stall.

⛔⛔ **Set it as your final act and send nothing after it.** "Touch `.quiet` and tell your
partner you have" is **self-defeating**: the watcher clears the flag on every incoming
message, so **the confirming message is what deletes the thing it reports.** Measured — the
flag was set, verified with `ls`, and gone a second later because the acknowledgement
arrived. Both observations were true, and neither described the state that existed next.

⚠️ The auto-clear is correct and should not be "fixed": it is what stops a stale flag
masking a real stall. **`.quiet` can only ever be set by an act followed by nothing.**

---

## Cost

Measured, roughly, per exchanged message:

- **Idle: zero tokens.** The poll is a shell loop.
- **Per message: ~6 tokens of overhead** beyond the message body itself.
- **Each watchdog alert costs a full model turn**, because it wakes the session. Use `.quiet` at terminal states or they add up.

⛔ **Do not add a scheduled job that periodically checks whether the watcher is alive.** It costs a full turn every fire — for a 30-minute interval that is ~48 turns a day, each re-sending your entire instruction context. It also guards a failure the *partner's* watchdog already detects: a session whose watcher died stops being woken, its transcript stops moving, and the partner reports it INACTIVE.

---

## Limitations — read these before relying on it

1. **The watcher is per-session and dies with the session, silently.** Every new session must re-arm it. Put the arming commands in the instruction file both sessions read at startup (`CLAUDE.md`), never in a prompt you paste by hand — a rule that lives in a chat message dies at the next handoff.
2. **On a re-arm, the whole inbox replays** as "already present". That is deliberate: hiding genuinely unread mail from a fresh session is worse than replaying an answered one. Check the highest number you have already answered before acting.
3. **A watchdog alert cannot tell an ordered silence from a stall.** That is what `.quiet` is for, and it is still your judgement.
4. **Polling, not events.** `inotifywait` is not available everywhere (notably Git Bash on Windows), so this polls. Detection is within `CS_POLL` seconds, default 2.
5. **Writes are atomic** (`.tmp` then rename) so a half-written file is never observed. Do not replace `cs-send.sh` with a plain redirect.
6. **Declaring done is not being done — archive the sessions.** A session that has written its
   handoff, said it is finished and gone quiet is **still armed**: the watcher runs inside the
   session process. From outside, a quiet session and a stopped session are indistinguishable,
   and the quiet one still wakes on anything written to its channel. **Archive both sessions and
   confirm `isRunning: false` — that flag is the only proof.** Skipping this is half of the
   two-pairs collision above; unstamped channel names are the other half.

7. **Clear with `rm *.md`, never `rm -rf` the folder.** The dotfiles must survive: `.<role>.seq` holds the message counter and `.<role>.transcript` holds the watchdog pointer.

   ⛔ **Why the counter is persisted rather than derived from the listing** — and this is worth reading even if you never clear the folder. If numbering comes only from the files present, clearing resets it to `0001` and **recycles filenames**. A recycled name that is still in a running watcher's seen-set produces no diff, and the watcher reconciles its state anyway, so **the message is swallowed silently — not delayed, gone, with no error anywhere.**

   ⭐ The sharp part: **clearing is normal housekeeping**, the kind of thing a tidy-up step recommends. The routine maintenance degraded the transport, and nothing in either script said so. `cs-selftest.sh` now has a regression check for it.

---

## Editing the scripts — read this first

You will almost certainly edit `cs-watch.sh` while your own watcher is running it. Two things follow, and both were learned the hard way:

**1. A running watcher is a snapshot of the script as it was at arm time.** Editing the file changes nothing for an already-armed watcher, and **nothing announces that it is stale**. One session here spent an entire message paying an overhead that had already been removed, because its watcher predated the fix. **After any change to `cs-watch.sh`, both sides must re-arm.**

**2. Do not rewrite the script in place while it is executing.** Bash reads a script lazily, by byte offset, as it runs. An in-place rewrite can make a running shell resume at the wrong offset and execute a fragment of a line — the failure mode is gibberish, not an error. A long-running `while` loop is usually already buffered past the edit, so you will probably get away with it, but that is luck rather than design.

✅ **Write to a temp file and `mv` it into place.** The rename is atomic and the running shell keeps the old inode until it exits.

## Configuration

All optional, via environment variables:

| var | default | meaning |
|---|---|---|
| `CS_DIR` | `.claude/cross-session` | where messages live |
| `CS_POLL` | `2` | seconds between checks |
| `CS_MAX_INLINE` | `150` | print bodies inline up to this many lines |
| `CS_QUIET_MIN` | `15` | minutes of silence before the INACTIVE alert |
| `CS_REPORT_MIN` | `25` | minutes of not-reporting before that alert |
| `CS_REALERT_MIN` | `30` | minimum gap between repeat alerts |
| `CS_PROJECTS_DIR` | `~/.claude/projects` | where session transcripts live |

---

## Templates

`templates/` has a block to paste into your `CLAUDE.md` and two starter prompts. The starter prompts are deliberately almost empty: **the only thing a starter prompt must do is assign the role**, because the instruction file cannot know which window is which. Everything else belongs in `CLAUDE.md`, where it survives.

---

## Support

This is free and MIT-licensed. If it saved you an afternoon and you feel like saying thanks, a tip is welcome — it buys you nothing except my gratitude.

**EVM** — Ethereum, Base, Arbitrum, Optimism, Polygon, or any EVM chain:

```
0x0D6A146753189CAbF46f42a77bBfad880B6f517e
```

**Solana:**

```
A4i6a89HXcaFrXRQ1JZUrmdFYL5cnZqyryqo357KuEbp
```

Send only on the network listed above the address. Anything sent on a chain the address does not support is unrecoverable.

---

## License

MIT — see `LICENSE`.
