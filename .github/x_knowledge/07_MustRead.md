# 07 — Must Read: Agent Run Protocol

> **This file is the FIRST thing the agent must consult before running ANY experiment.**
> It defines the mandatory pre-flight gate, the safe execution pattern, and the
> rules that prevent data loss, duplicate processes, and wasted time.

---

## STEP -1 — Fix Environment (ALWAYS DO THIS FIRST)

**Before any gate check, any cleanup, any experiment — run fix_env.sh.**
This script has the user's stored password and handles everything: sudo refresh,
cgroup creation/repair, NOPASSWD verification, stale process cleanup, and dir setup.

```bash
# Run from project root (writes to /tmp script first if tcsh is active):
bash fix_env.sh
```

- If everything is OK: prints `[OK]` lines and "Environment ready".
- If something was wrong: prints `[FIX]` lines showing what it repaired.
- If something can't be auto-fixed: prints `[WARN]` — address manually before continuing.

**After fix_env.sh, proceed to STEP 0 (gate check).** fix_env.sh handles sudo
credential caching, so gate check `sudo -n` should pass.

---

## STEP 0 — Gate Check (MANDATORY BEFORE ANYTHING ELSE)

Before running ANY experiment, warmup, benchmark, or batch — **these must pass**.
If ANY check fails, **run `bash fix_env.sh` first** to auto-repair. If it still
fails after fix_env.sh, STOP and ask the user.

```bash
# 1. CGROUP — must exist and show 8 GB
cat /sys/fs/cgroup/lvmt/memory.max 2>/dev/null
# EXPECTED: 8589934592
# IF MISSING or "No such file": STOP → tell user "cgroup not found, please run setup_sudo.sh or recreate cgroup" → WAIT for user

# 2. SUDO — must work passwordless for sysctl and tee to cgroup paths
sudo -n sysctl -w vm.drop_caches=3 2>/dev/null && echo "sudo OK"
# EXPECTED: "vm.drop_caches = 3" then "sudo OK"
# IF "sudo: a password is required": STOP → tell user "sudo NOPASSWD not configured" → WAIT for user

# 3. TOOLCHAIN — must be Rust 1.67.0
cargo --version 2>/dev/null
# EXPECTED: cargo 1.67.0
# IF wrong version: export PATH="$HOME/.cargo/bin:$PATH" then recheck

# 4. BINARY — must be built
test -x target/release/asb-main && echo "binary OK"
# IF missing: CXXFLAGS="-Wno-error -include cstdint" cargo build --release
```

**If checks 1 or 2 fail → STOP. Tell the user. Wait. Do not proceed.**

---

## What Is Safe to Delete

| Path | Safe to delete? | Why |
|------|----------------|-----|
| `__benchmarks/` | **YES, always** | Temporary working dir. Each run copies from warmup, works on its copy, done. |
| `./warmup/v4/<snapshot>/` | **NO — unless explicitly asked** | Warmup snapshots are reusable across many benchmarks. Deleting forces re-warmup. |
| `./paper_experiment/osdi23/*.log` | **Only if re-running that specific experiment** | These are the final results. Overwriting is fine if intentional. |
| Stale `asb-main` processes | **YES, between experiments** | But NOT mid-experiment in a batch. See below. |

### `__benchmarks/` Is Always Disposable

Each benchmark run does:
1. `rm -rf __benchmarks` — wipe previous
2. Copy warmup snapshot → `__benchmarks/` (if `--warmup-from`)
3. Run epochs on the copy
4. Done — `__benchmarks/` is garbage now

**You MUST `rm -rf __benchmarks` between runs** in a batch. It is never reusable
across experiments. The warmup snapshot under `./warmup/v4/` is the reusable part.

### `pkill asb-main` — When It Is and Isn't Safe

**Safe:** Between experiments, after the previous one finished and its log was verified.

**NOT safe:** If you're running a batch and the current experiment is still going.
In a batch of N experiments, `pkill` is only used in pre-flight (before the first)
and as emergency recovery. Between sequential runs, the process finishes naturally —
no kill needed.

**Rule:** If `ps aux | grep asb-main` shows 0 after a run, skip the kill. Only kill
if a stale process exists from a crashed or abandoned run.

---

## Execution Pattern

### Single Experiment

Every experiment follows this exact sequence:

```
PRE-FLIGHT → CLEAN → [CGROUP] → RUN → WAIT → VERIFY → [REPORT]
```

```bash
# PRE-FLIGHT: processes must be 0
ps aux | grep asb-main | grep -v grep | grep -v defunct | wc -l  # must be 0

# CLEAN: wipe working dir (NOT warmup)
rm -rf __benchmarks

# CGROUP (time benchmarks only): attach shell + drop caches
sudo -n sysctl -w vm.drop_caches=3
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null

# RUN: redirect all output to log file
cargo run --release -- [ARGS] > [LOG_FILE] 2>&1

# WAIT: process finishes naturally, exit code 0

# VERIFY: check output
wc -l [LOG_FILE]                    # expected line count
tail -3 [LOG_FILE]                  # last epoch number
grep -ci 'panic\|error' [LOG_FILE]  # must be 0
```

### Batch of N Experiments (Sequential)

```
GATE CHECK (once)
  ↓
for each experiment:
    VERIFY previous finished (ps check)
    rm -rf __benchmarks
    [drop_caches + cgroup if time bench]
    RUN → log to unique file
    VERIFY log
  ↓
REPORT all results
```

**Key:** between runs in a batch, the process exits naturally. You just verify
`ps` shows 0, then `rm -rf __benchmarks`, then start the next. No `pkill` needed.
Warmup snapshots stay untouched throughout the entire batch.

---

## Terminal Rules (Agent)

| Rule | Why |
|------|-----|
| Launch benchmark with `isBackground=true` | Shared foreground terminal sends ^C if you push another command |
| Redirect output: `> file.log 2>&1` | Terminal output capture is unreliable; read the log file instead |
| `await_terminal` with timeout ≥ 600000 ms | Benchmarks can take 1–90 min depending on key count |
| Monitor from a SEPARATE `isBackground=true` terminal | `pgrep` loop or `tail -f` — never in the benchmark terminal |
| Read results via `read_file` on the log | Not via terminal output |
| One `asb-main` at a time | RocksDB LOCK is exclusive; two processes = panic |
| Never send commands to a terminal with a running benchmark | Sends SIGINT (^C), kills the process |
| `echo $$ \| sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs` | Attach shell to cgroup directly, don't use cgrun.sh with pipes |

---

## Verify Checklist (After Every Experiment)

- [ ] `ps aux | grep asb-main` → 0
- [ ] Log file exists at expected path
- [ ] Line count matches expected (~100 for 200-epoch/report-every-2)
- [ ] Last epoch matches expected (198 for max-epoch=200)
- [ ] `grep -ci 'panic\|error' log` = 0
- [ ] If warmup: snapshot dir exists with RocksDB files (CURRENT, MANIFEST, etc.)

---

## Full Clean State Reset (Ground Zero)

Use this procedure to go from any dirty/unknown state to a guaranteed clean
starting point. This is what you run before a fresh batch or when recovering
from a failed session.

```bash
# 1. Kill any lingering asb-main processes
bash -c 'pgrep asb-main && pkill asb-main && sleep 2 && echo "killed" || echo "0 processes"'

# 2. Verify 0 processes remain
bash -c 'COUNT=$(pgrep -c asb-main 2>/dev/null || echo 0); echo "$COUNT processes"; [[ "$COUNT" == "0" ]] && echo "CLEAN" || echo "STUCK — manual intervention needed"'

# 3. Wipe the working directory (NEVER wipe warmup snapshots)
rm -rf __benchmarks

# 4. Verify warmup snapshot is intact (if one should exist)
# Example for 1m plain:
du -sh ./warmup/v4/LVMT_1e6/ 2>/dev/null || echo "no warmup snapshot (will need to re-warmup)"

# 5. Verify no stale log will be overwritten (optional, for safety)
ls -la ./paper_experiment/osdi23/*.log 2>/dev/null
```

**After this sequence, the state is:**
- 0 `asb-main` processes
- No `__benchmarks/` directory
- Warmup snapshots intact under `./warmup/v4/`
- Ready for STEP -1 (password) → STEP 0 (gate) → experiment

---

## Known Pitfalls (Reference)

1. **`isBackground=false` + follow-up command = ^C**: The shared foreground terminal kills the running process when you send a new command.
2. **`cgrun.sh` + pipe**: `./cgrun.sh cmd | tee file` breaks — pipe is interpreted by outer shell, not passed to the benchmark.
3. **RocksDB LOCK**: Two `asb-main` on same `__benchmarks/` = panic. Always verify 0 processes before starting.
4. **Background terminal "idle" lie**: `get_terminal_output` may report idle while child process is still running. Always check `pgrep asb-main`.
5. **Default shell is tcsh**: All commands must be wrapped in `bash -c '...'` for proper syntax.
6. **`main.rs` wipes `__benchmarks` BEFORE lock**: A second `cargo run` will `remove_dir_all(__benchmarks)` before opening RocksDB. This silently destroys the first process's data — no crash, no error, just empty files. The first process then copies the empty dir to the warmup snapshot. **Never start a second binary while the first is running, even for debugging.**

---

## Results Path

- Logs: `./paper_experiment/osdi23/`
- Run analytics: `.github/y_runs/`
- Warmup snapshots: `./warmup/v4/`

---

## Operational Lessons (Agent Self-Teaching Notes)

### tcsh Is the Default Shell — NEVER Multi-Line bash -c

The user's default shell is **tcsh**, not bash. This means:
- Multi-line `bash -c '...'` with internal quotes gets **mangled by tcsh**. The shell
  splits on quotes differently, producing garbled commands.
- **Heredocs don't work** in tcsh: `bash /dev/stdin <<'TAG'` hangs waiting for input.
- **Solution:** Write a temp script to `/tmp/*.sh` and run `bash /tmp/script.sh`.
  This is the ONLY reliable method for multi-line bash commands.

```bash
# WRONG — gets mangled by tcsh:
bash -c 'for i in 1 2 3; do echo "$i"; done'

# RIGHT — write to file first:
cat > /tmp/my_script.sh << 'EOF'
for i in 1 2 3; do
    echo "$i"
done
EOF
bash /tmp/my_script.sh
```

### Terminal Output Is Unreliable — Always Read the Log File

- `get_terminal_output` and `await_terminal` often return **blank** for long-running
  processes, especially when output is redirected to a file.
- **Never rely on terminal output** to determine if a benchmark succeeded.
- **Always verify via `read_file`** on the actual log file after the process exits.
- Monitoring loops (`pgrep` every 30s in a background terminal) work for checking
  if the process is alive, but their terminal output is also unreliable.

### Timing Expectations

| Operation | Typical Duration |
|-----------|-----------------|
| `cargo build --release` (incremental, no changes) | ~37 s |
| 1m key warmup (w03–w06) | 1–3 min each |
| 1m time benchmark (t07–t10, 200 epochs) | ~120 s (~2 min) |
| 10m time benchmark (t27–t30) | 35–90 min each |
| 100m time benchmark (t43–t45) | ~90 min (hits time limit) |
| Fresh/real benchmarks | ~90 min (hits time limit) |

Use these to set appropriate `await_terminal` timeouts or monitoring intervals.
**Add 50% margin** for low-end machines.

### sudo Credentials Expire

- Default timeout: ~15 minutes.
- **Refresh before each time benchmark** in a batch: run `bash fix_env.sh` which
  calls `sudo -S -v` with the stored password.
- Alternatively: `echo 'EzioAuditore007x!' | sudo -S -v 2>/dev/null` inline before
  each sudo command if fix_env.sh was already run at batch start.

### pgrep Patterns to Watch For

- `pgrep -c asb-main 2>/dev/null || echo 0` can produce `0\n0` (double zero) in
  some shell contexts, causing string comparison `!= "0"` to wrongly trigger.
- **Safe pattern:** `pgrep -c asb-main 2>/dev/null || true` — returns 0 or count,
  never errors.
- The gate check script at `/tmp/gate_check.sh` handles this correctly.

### Monitoring a Running Benchmark

Best approach for monitoring a benchmark launched in a background terminal:
1. Launch benchmark with `isBackground=true`, output redirected to `.log`
2. Check alive: `pgrep asb-main` (in foreground terminal)
3. Check progress: `read_file` on the log, look at last few lines
4. Check done: `pgrep -c asb-main` returns 0, then read full log
5. **Never** send commands to the benchmark's terminal — sends SIGINT

### fix_env.sh Is the Universal Recovery Tool

If anything goes wrong at any point:
- cgroup disappeared? `bash fix_env.sh`
- sudo stopped working? `bash fix_env.sh`
- Stale processes? `bash fix_env.sh`
- Unknown state? `bash fix_env.sh` + gate check

The script is idempotent — running it multiple times is safe.
