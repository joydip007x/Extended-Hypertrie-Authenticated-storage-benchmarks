# 08 — Non-Panic Scenarios & 8 GB Constraint

> **Purpose:** Document situations that LOOK alarming but are NORMAL and EXPECTED.
> No agent or session should panic, abort, or flag errors for these scenarios.
> Read this before interpreting any benchmark output as "broken."

---

## The 8 GB Rule (Paper Requirement)

The original OSDI'23 paper specifies an **8 GB memory limit** via cgroup v2 for time
benchmarks. This is a deliberate constraint to simulate memory-limited production
environments (e.g., Ethereum nodes). We enforce this exactly:

```
/sys/fs/cgroup/lvmt/memory.max = 8589934592  (8 GB)
```

**No matter how slow a benchmark runs under this constraint, the result is valid.**
The paper measures performance UNDER memory pressure — that's the whole point.
If a single-shard experiment takes 90 minutes to complete 20 epochs instead of 200,
that IS the result. Do not:
- Kill it thinking it's stuck
- Increase the memory limit "to help"
- Skip it thinking something is wrong
- Panic about D-state (uninterruptible I/O) processes

---

## Non-Panic Scenario List

### 1. Process in D State (Uninterruptible I/O Sleep)

**What you see:**
```
ps -p <PID> -o state=
D
```

**What it means:** The process is waiting on disk I/O. Under the 8 GB cgroup,
RocksDB frequently triggers page reclaim because the database + cache exceeds
available memory. The kernel pages out data, then pages it back in on the next
access — causing the process to block in `D` state.

**Is this a problem?** NO. It is the expected behavior for memory-constrained
benchmarks. The process IS making progress, just very slowly. Check the log file
periodically — new epoch lines will appear, just with long gaps.

**What to do:** Nothing. Let it run. Check log file (`tail -1 <logfile>`) every
few minutes to confirm epochs are still advancing.

---

### 2. Extremely Slow Throughput (< 1000 ops/sec)

**What you see:**
```
2: 298.284 s >     670 ops, 1491.419 us/op
```

**Why it happens:** Single-shard LVMT (`--shards 1`) creates a monolithic database
(4.8 GB for 1M keys) that cannot fit in the 2048 MB cache. Every node access
triggers a cache miss → disk read → memory pressure → page eviction → thrashing.

**Expected ranges by shard count (1M keys):**

| Variant | Steady ops/sec | Normal? |
|---------|---------------|---------|
| Plain   | 150k–220k     | YES     |
| 64 shard| 120k–180k     | YES     |
| 16 shard| 100k–125k     | YES     |
| 1 shard | 300–1000      | YES — this is the paper's point |

**What to do:** Let it run until `--max-time 5400` is reached or all epochs complete.

---

### 3. Benchmark Hits max-time Limit (5400s) Before 200 Epochs

**What you see:** The log file stops at, say, epoch 20 instead of 198. The process
exits cleanly — no error, no panic.

**Why it happens:** The `--max-time 5400` flag caps wall time at 90 minutes. Slow
experiments (s1 variants, large key counts) won't finish all 200 epochs within this
window. This is BY DESIGN — the paper reports whatever was achieved within the time
limit.

**Is this a failure?** NO. A time-capped run with fewer epochs IS a valid result.
The y_runs analysis should note "hit max-time limit at epoch N."

**What to do:** Read the final log line, document the epoch count, proceed to the
next experiment.

---

### 4. Write Amplification > 10×

**What you see:**
```
Write amp 11.965
```

**Why:** Single-shard LVMT writes ~1 million AMT access entries per 2-epoch window
compared to ~65k for 64 shards and ~0 for plain. This is the cost of maintaining
a single, large AMT tree without partition.

**Normal ranges:**

| Variant | Write Amp | Normal? |
|---------|-----------|---------|
| Plain   | 0.97–0.98 | YES     |
| 64 shard| 1.13–1.16 | YES     |
| 16 shard| 1.64–1.70 | YES     |
| 1 shard | 11.9–14.0 | YES — expected for single shard |

---

### 5. Read Amplification > 10×

**What you see:**
```
Read amp 14.008
```

Same story as write amplification. Single-shard experiments have extremely high
read amplification because the full AMT tree must be traversed from disk, while
sharded variants keep per-shard trees smaller and more cache-friendly.

---

### 6. Warmup Snapshot Is Very Large (Several GB)

**What you see:**
```
du -sh ./warmup/v4/LVMT1_1e6/
4.8G    ./warmup/v4/LVMT1_1e6/
```

**Why:** Single-shard LVMT stores ALL keys in one RocksDB instance with one AMT.
The lack of sharding means no parallelism in data layout, resulting in much larger
on-disk representation. Compare: plain=144MB, s64=177MB, s16=276MB, s1=4.8GB.

**Is this a disk space problem?** Only if you're running many large batches. For
1M keys it's manageable. For 10M+ keys with s1, snapshots can be 10–50+ GB.
Always `df -h .` before starting a batch.

---

### 7. cgroup Memory Nearly Full (7.9/8.0 GB)

**What you see:**
```
cat /sys/fs/cgroup/lvmt/memory.current
8489271296   # ~7.9 GB out of 8.0 GB
```

**Why:** The benchmark deliberately pushes memory to the limit. RocksDB block cache
(2048 MB) + database pages + kernel buffers consume nearly all 8 GB. The OOM killer
does NOT activate because cgroup limits are soft enough for the workload.

**What to do:** Nothing. This is the intended operating condition. If the OOM killer
DOES trigger (process killed with signal 9), that's a different problem — reduce
cache size or skip that experiment variant.

---

### 8. Epoch Data Lines Show Every-Other-Epoch Reporting

**What you see:**
```
     2:   2.763 s >  72,376 ops
     4:   4.878 s > 116,014 ops
     6:   6.861 s > 100,887 ops
```

**Why:** The default `--report-epoch 2` means data is printed every 2 epochs.
This is normal — there's no missing data. Real-trace experiments use
`--report-epoch 25` and show every 25th epoch.

---

### 9. Throughput Variance Within a Run (±20%)

**What you see:** Ops/sec fluctuates between, say, 120k and 178k across epochs
within the same experiment.

**Why:** RocksDB background compaction, Linux page cache dynamics, and cgroup
memory pressure all cause throughput to oscillate. This is NORMAL NOISE, not
an error. The steady-state average is what matters.

**Typical variance by variant:**
- Plain: ±8%
- 64 shard: ±20%
- 16 shard: ±7%
- 1 shard: very erratic (can 2× between consecutive epochs)

---

### 10. `cargo run --release` Shows "Compiling" Lines Before Benchmark

**What you see:**
```
Compiling asb-main v0.1.0
    Finished release [optimized] target(s) in 36.69s
```

**Why:** Cargo checks for source changes before running. Even if nothing changed,
the dependency check can take 1–5 seconds. If sources DID change, a full rebuild
takes ~37 seconds. This is normal — the actual benchmark starts after "Finished."

**What to do:** Nothing. The benchmark output follows after compilation.

---

### 11. Log File Has Only ~20 Lines of "warmup depth N" Before Data

**What you see:**
```
Testing LVMT with 1e6 addresses
warmup from ./warmup/v4/LVMT_1e6/
warmup depth 1
warmup depth 2
...
warmup depth 16
Start warming up
Warm up done
     2:   2.763 s > ...
```

**Why:** The "warmup depth" lines are the snapshot restoration phase — the benchmark
loading the pre-populated database from disk. This is faster than rebuilding from
scratch. The "Warm up done" line marks when the actual timed benchmark begins.

---

### 12. Terminal Shows "idle" But Process Is Still Running

**What you see:** `get_terminal_output` or `await_terminal` returns without new output,
suggesting the terminal is done.

**Reality:** The benchmark IS running but its output goes to a log file (`> file.log 2>&1`),
so the terminal itself appears idle.

**What to do:** Check `pgrep asb-main` to see if the process exists. Check the log
file with `tail -1 <logfile>` to see the latest epoch. Never rely on terminal output.

---

## Summary Decision Tree

```
Is the process alive?  (pgrep asb-main)
├── YES → Is the log file growing?  (tail -1 logfile)
│   ├── YES → NORMAL. Let it run.
│   └── NO → How long since last epoch?
│       ├── < 10 minutes → NORMAL for s1. Wait.
│       └── > 30 minutes → Possibly stuck. Check D state, cgroup OOM events.
└── NO → Did it exit cleanly?  (check last log line)
    ├── Last line is an epoch → CLEAN EXIT (max-time or max-epoch hit)
    └── Last line is "panic" or garbled → ERROR. Document and re-run.
```
