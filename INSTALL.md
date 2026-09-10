# Install it by asking Claude Code to do it

You already have an agent with file access. Use it.

1. Clone or download this repo **anywhere** — it does not need to live inside your project.
2. Open Claude Code in **your own project**, and give it read access to wherever you put this repo.
3. Paste the prompt below.

It asks you two questions, copies five scripts in, wires up your `CLAUDE.md`, and finishes by running
the self-test and showing you the result — so you end with `11 passed, 0 failed` rather than a claim
that it worked.

Manual steps are in the [README](README.md#install) if you would rather do it yourself.

---

## The prompt

```text
Install the claude-cross-session message bus into THIS project. The kit is at:
<PATH TO THE CLONED REPO>

Read that folder first — its README explains what each script does and the hazards.
Then do the following, and stop and ask me if any step is ambiguous.

FIRST, ASK ME TWO THINGS AND WAIT FOR MY ANSWER:
  1. The two role names for this pair (e.g. alice/bob, lead/worker, advisor/impl).
     Do NOT pick them for me and do NOT default them.
     If I am likely to run more than one pair in this project over time, tell me to
     include a stamp (alice_0930 / bob_0930) and tell me why: the bus addresses by
     PREFIX, so a reused name means a new pair silently joins a dead pair's
     conversation and replays its inbox.
  2. Whether I want the watchdog (it needs cs-register.sh and a marker per session).
     The bus works without it.

THEN:
  - Copy scripts/cs-*.sh into ./scripts/ and chmod +x them.
    ⛔ If a file of that name already exists and differs, STOP and show me the diff.
       Do not overwrite anything of mine without telling me.
  - Create .claude/cross-session/ and add that path to .gitignore (messages are
    chatter, not source). Leave the scripts TRACKED — if they are untracked, a
    git stash or a fresh clone silently removes what my instructions tell every
    new session to run.
  - Append the contents of templates/CLAUDE.md.snippet.md to my CLAUDE.md, with the
    role names filled in, inside a clearly marked block:
        <!-- BEGIN claude-cross-session -->  ...  <!-- END claude-cross-session -->
    ⛔ Do not reformat, reorder or rewrite anything else in that file.
    If I have no CLAUDE.md, create one containing only that block.
  - Do NOT modify any other file, and do NOT touch anything outside this project.

FINALLY, AND DO NOT SKIP THIS:
  - Run scripts/cs-selftest.sh and paste the output verbatim.
    It ends with "N passed, M failed". If anything failed, tell me plainly what
    broke rather than summarising it as fine.
  - Then tell me, in a short list: every file you created, every file you changed,
    the two role names, and the exact register + watch commands each of my two
    sessions must run — the watcher must be armed with the Monitor tool and
    persistent: true, never as a plain background job.
```

---

## After it finishes

Open your two sessions and run the commands it gives you. The arming commands belong in your
`CLAUDE.md`, not in a prompt you paste by hand — a rule that lives in a chat message dies at the next
handoff, and that is the single most common way this ends up half-installed.

Then read two sections of the README before you rely on it:

- **[Register only the channel you send on](README.md)** — registering the one you only *read* aims
  your partner's stall alarm at yourself, and nothing errors.
- **[Limitations](README.md#limitations--read-these-before-relying-on-it)** — in particular that the
  watcher can die mid-session, and that the notice reads like routine noise.
