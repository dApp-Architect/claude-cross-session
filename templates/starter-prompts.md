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

## Handing a long job to a fresh session — the standby, and the promotion

On a job longer than one context window, start the successor EARLY and leave it idle, so its window
is fresh when you promote it. Two things about that are easy to get wrong and both are silent.

### The standby's prompt

```
You are <ROLE> — STANDBY ONLY. Do not act yet.

  scripts/cs-register.sh <your-own-channel> selfid-<LONG-RANDOM>

Then arm a watcher with the Monitor tool, persistent: true, on: <your-own-channel>
Wait for the literal "WATCHER ARMED" line — that line is the proof, not the tool's
acknowledgement.

Then read NOTHING else and do NOTHING until a promotion message arrives on that channel.
A standby that reads while waiting spends the window the next generation will need.

⛔⛔ ONE EXCEPTION, AND IT IS THE ONLY ONE. If you are ever notified that your Monitor
task failed or exited — for example "script failed (exit 4)" — THAT IS NOT NEWS, IT IS
THE LOSS OF YOUR ONLY SENSE. Re-arm immediately, before anything else, and say so in one
line. Skipping it costs you every future message, including your own promotion.
```

⛔ **Do not restate the rules in the standby prompt beyond that carve-out.** A starter is a SECOND
COPY of your instruction file and it drifts. Point at the file; carry only state.

### Before you promote it — check the pointer is a pulse

```bash
stat -c '%y' "$(cat .claude/cross-session/.<successor>.transcript)"
```

**Minutes: alive. Hours: you are about to promote nobody.** A registration proves a pointer, never a
pulse — one promotion here went to a standby whose transcript had not moved in 21 hours.

### If it does not ACK — wake it, do not write it off

A standby that has gone deaf is usually still **running**. Direct-message it in its own window
(`send_message` / SendMessage by full session id); that reaches a session the bus cannot.
**Only ask the human to start a new one if the direct wake also fails.**

```
⛔⛔ YOU ARE THE SUCCESSOR AND YOU ARE PROMOTED. Your watcher is dead — that is why
this is arriving in your window instead of on the bus.

RE-ARM FIRST, BEFORE READING ANYTHING. You are deaf until you do:
  scripts/cs-register.sh <your-own-channel> selfid-<LONG-RANDOM>
  then arm the watcher (Monitor tool, persistent:true) on <your-own-channel>

Then read these, from disk — you were never notified of them:
  .claude/cross-session/<your-channel>_0001.md   (and any later ones)

ACK on <predecessor's own inbox channel> when you are up.
```

⚠️ **Check the session id is the successor's and not your own.** A wake aimed at yourself does
nothing and looks exactly like a successor that will not answer.

### In the promotion message — say WHERE to ACK

> ACK on `<my own inbox channel>`, not on the shared send channel.

Each session watches its **partner's** channel, so a successor ACKing on the channel you send on is
ACKing somewhere **you do not watch**. *"Never retire on the send — retire on the ACK"* is correct
and, without this line, unachievable: one session held for an ACK it could not receive for 23
minutes, and kept sending meanwhile, so the partner briefly had two sessions giving it instructions.

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
