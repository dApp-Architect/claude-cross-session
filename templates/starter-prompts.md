# Starter prompts

Two prompts, one per window. Replace `ROLE_A` / `ROLE_B` with your chosen names and adjust
the reading list to your project.

⭐ **These are deliberately almost empty.** The only thing a starter prompt must do is
**assign the role**, because `CLAUDE.md` cannot know which window is which. Everything else
belongs in `CLAUDE.md`, where it survives a handoff. Anything you put here applies only when
you remember to paste it.

---

## Window A

```
You are ROLE_A in a two-session pair. The other window is ROLE_B.

FIRST — name the pair. Run this in the shell, do not guess the time:
  date +%Y-%m-%d_%H%M
You CANNOT rename yourself, so rename your PARTNER: list my sessions, find the other one
(same working directory, most recently active), tell me its id and current title, and
rename it to exactly "ROLE_B — <project> " followed by that output. If it does not exist
yet, say so and rename it as soon as it appears.

SECOND — arm the file bus, USING THE PAIR STAMP FROM STEP ONE IN THE CHANNEL NAMES.
The channel is a plain string: if another pair is running in this same directory with
the same names, you will silently join THEIR conversation. The stamp prevents it.
  bash scripts/cs-register.sh ROLE_A_<stamp> selfid-a-<unique>
then arm the watcher with the Monitor tool, persistent: true:
  bash scripts/cs-watch.sh ROLE_B_<stamp>
and send with:
  echo "..." | bash scripts/cs-send.sh ROLE_A_<stamp>
⛔ Run these from the SAME directory every time — the bus is a PATH, not a name.

THIRD — read CLAUDE.md, then whatever your project uses for current state and the most
recent handoff. The handoff NAMES the first task. Start there. Do not re-pick from a list
or re-plan what was already decided.

Confirm the rename, the bus, and what the handoff says the first task is.
```

## Window B

```
You are ROLE_B in a two-session pair. The other window is ROLE_A.

FIRST — name the pair. Run this in the shell, do not guess the time:
  date +%Y-%m-%d_%H%M
You CANNOT rename yourself, so rename your PARTNER: list my sessions, find the other one
(same working directory, most recently active), tell me its id and current title, and
rename it to exactly "ROLE_A — <project> " followed by that output. If it does not exist
yet, say so and rename it as soon as it appears.

SECOND — arm the file bus, USING THE PAIR STAMP FROM STEP ONE IN THE CHANNEL NAMES.
The channel is a plain string: if another pair is running in this same directory with
the same names, you will silently join THEIR conversation. The stamp prevents it.
  bash scripts/cs-register.sh ROLE_B_<stamp> selfid-b-<unique>
then arm the watcher with the Monitor tool, persistent: true:
  bash scripts/cs-watch.sh ROLE_A_<stamp>
and send with:
  echo "..." | bash scripts/cs-send.sh ROLE_B_<stamp>
⛔ Run these from the SAME directory every time — the bus is a PATH, not a name.

THIRD — read CLAUDE.md, then whatever your project uses for current state and the most
recent handoff. The handoff NAMES the first task. Start there. Do not re-pick from a list
or re-plan what was already decided.

Confirm the rename, the bus, and what the handoff says the first task is.
```

---

## When the pair is finished — ARCHIVE BOTH SESSIONS

Declaring done and being done are different things. A session that has written its handoff,
said it is finished and gone quiet is **still armed**: its watcher runs inside the session
process, so it keeps waking on anything written to its channel.

⛔ **From outside, a quiet session and a stopped session look identical.** Archive both
sessions and confirm `isRunning: false` — that flag is the only proof.

⭐ **This is not housekeeping.** A pair that was believed finished, but never stopped, is how
a later pair's dispatch reaches two live workers at once. Combined with unstamped channel
names it is a silent, repeatable failure: both workers do the right thing and race each other
on the same files.

---

## If you are leaving the sessions unattended

Add a paragraph like this to both, adjusted to your own authority rules:

```
I AM AWAY, AND I WANT WORK TO CONTINUE. Run everything that does not need me present. Do
not idle waiting for me. Batch everything that DOES need me into one running list I can
action from my phone, each item self-contained enough to approve without reading back
through the session.
```
