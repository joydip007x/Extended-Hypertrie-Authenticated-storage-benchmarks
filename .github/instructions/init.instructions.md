---
description: Most needed info or knowledge is found in `.github/x_knowledge/`
# applyTo: 'Most needed info or knowledge is ' # when provided, instructions will automatically be added to the request context when the pattern matches an attached file
---

<!-- Tip: Use /create-instructions in chat to generate content with agent assistance -->

Provide project context and coding guidelines that AI should follow when generating code, answering questions, or reviewing changes.

## Before ANY experiment run

**Read `.github/x_knowledge/07_MustRead.md` FIRST.** It contains the mandatory gate check
(cgroup, sudo, toolchain) and the execution protocol.

**If anything fails (cgroup missing, sudo broken, stale processes):** run `bash fix_env.sh`
from the project root. This script auto-fixes sudo credentials, cgroup creation/repair,
NOPASSTD sudoers, stale process cleanup, directory setup, and toolchain verification.
It is idempotent — safe to run multiple times. The script is chmod 600 and gitignored
(contains the user's sudo password).

## Key paths

- Knowledge base: `.github/x_knowledge/`
- Run analytics: `.github/y_runs/` (naming: `{expID}_{algo}_{keys}_{variant}_{YYYYMMDD}.md`)
  - **Collision rule:** If a file with the same name already exists, rename the OLD file
    to `filename_Old_01.md` (increment `_Old_02`, `_Old_03`, etc.), then create the new
    file with the canonical name. Latest analysis always has the clean name.
- Handoff notes: `.github/hand_off/` (session summaries for next-session context)
- Non-panic guide: `.github/x_knowledge/08_NonPanic_Scenarios.md` (normal-but-alarming situations)
- Experiment reference: `.github/x_knowledge/06_only_LVMT_1.md` (103 LVMT experiments, individual commands)
- Batch plans: `.github/x_knowledge/06_only_LVMT_2.md` (13 named batches, all 103 experiments)
- Logs: `./paper_experiment/osdi23/`
- Warmup snapshots: `./warmup/v4/` (reusable, NEVER delete without asking)
- Environment fix: `fix_env.sh` (auto-fix sudo, cgroup, stale processes — run on ANY issue)