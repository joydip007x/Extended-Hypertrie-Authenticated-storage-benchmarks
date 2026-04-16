# Run Report: only-lvmt-t07 — LVMT 1M Time Benchmark (Plain)

**Experiment ID:** only-lvmt-t07  
**Algorithm:** LVMT  
**Key count:** 1,000,000 (1m)  
**Variant:** time (no stat), plain  
**Date:** 2026-04-15 (run 2 — clean redo after protocol fix)  
**Status:** CLEAN — 0 kills, 0 duplicates, 0 errors, 0 LOCK conflicts

---

## Environment

| Parameter       | Value                           |
|-----------------|---------------------------------|
| Machine         | fcs-0033                        |
| OS              | Linux (cgroup v2)               |
| Rust toolchain  | 1.67.0                          |
| Memory limit    | 8 GB (cgroup `/sys/fs/cgroup/lvmt`) |
| `drop_caches`   | 3 (before benchmark start)      |
| `CXXFLAGS`      | `-Wno-error -include cstdint`   |

## Commands

### Warmup (w03)

```bash
cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt
```

| Metric            | Value              |
|-------------------|--------------------|
| Warmup epochs     | 20                 |
| Warmup depth      | 16 levels          |
| Warmup lines      | 33                 |
| Snapshot size     | 144 MB             |
| Snapshot path     | `./warmup/v4/LVMT_1e6/` |

### Time Benchmark (t07)

```bash
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- \
  --max-time 5400 -a lvmt --no-stat --max-epoch 200 \
  --warmup-from ./warmup/v4 -k 1m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_1m.log 2>&1
```

---

## Results Summary

| Metric                    | Value           |
|---------------------------|-----------------|
| Total epochs              | 200 (reported up to epoch 198) |
| Total wall time           | 118.829 s       |
| Compilation time          | 36.69 s         |
| Avg time per epoch        | ~0.594 s        |
| Log lines                 | 121             |
| Data lines                | 99 (epochs 2–198, step 2) |
| Log path                  | `./paper_experiment/osdi23/time_lvmt_1m.log` |
| Errors / panics           | 0               |
| Processes killed          | 0               |

---

## Throughput Progression

### Ramp-up Phase (epochs 2–54)

| Epoch | Time (s) | Ops/sec  | us/op  | Read Amp |
|------:|--------:|---------:|-------:|---------:|
|     2 |   2.763 |   72,376 | 13.817 |    1.779 |
|    10 |  10.068 |  122,340 |  8.174 |    0.999 |
|    20 |  17.711 |  139,755 |  7.155 |    0.977 |
|    30 |  24.569 |  150,430 |  6.648 |    0.976 |
|    40 |  31.001 |  155,654 |  6.424 |    0.975 |
|    50 |  37.202 |  161,265 |  6.201 |    0.975 |

**Observation:** Read amplification drops from 1.779 → 0.975 as the cache
warms. Throughput ramps from 72k to 161k ops/sec over the first ~50 epochs.

### Burst Phase (epochs 56–68)

| Epoch | Time (s) | Ops/sec  | us/op |
|------:|--------:|---------:|------:|
|    56 |  40.723 |  185,200 | 5.400 |
|    58 |  41.793 |  186,946 | 5.349 |
|    60 |  42.709 |  218,462 | 4.577 |
|    62 |  43.622 |  218,971 | 4.567 |
|    64 |  44.574 |  210,089 | 4.760 |
|    66 |  45.515 |  212,421 | 4.708 |
|    68 |  46.450 |  214,091 | 4.671 |

**Observation:** Sudden throughput jump to 185–219k ops/sec. Likely RocksDB
compaction completing + full caching achieved. Peak: **218,971 ops/sec**
at epoch 62.

### Steady-State Phase (epochs 70–198)

| Metric          | Value                    |
|-----------------|--------------------------|
| Data points     | 65                       |
| Peak ops/sec    | 204,168 (epoch 164)     |
| Trough ops/sec  | 164,947 (epoch 102)     |
| Typical range   | 170,000–190,000         |
| Read amp        | 0.974–0.977             |
| Write amp       | 0.974–0.977             |
| Avg levels      | 1.669–1.677             |
| Access writes   | [0, 0, 0, 2] (constant) |
| Data writes     | 200,000 0 (constant)    |

**Selected steady-state data points:**

| Epoch | Time (s) | Ops/sec  | us/op |
|------:|--------:|---------:|------:|
|    80 |  53.362 |  169,009 | 5.917 |
|   100 |  64.857 |  170,836 | 5.854 |
|   120 |  76.155 |  178,459 | 5.604 |
|   140 |  86.859 |  186,309 | 5.367 |
|   160 |  97.907 |  181,644 | 5.505 |
|   180 | 108.719 |  170,829 | 5.854 |
|   198 | 118.829 |  177,441 | 5.636 |

---

## Key Observations

1. **Cache warmup takes ~50 epochs.** Read amp is 1.78× at epoch 2, but settles
   to ~0.975 by epoch 24. Throughput keeps climbing until ~55.

2. **Burst phase at epochs 56–68.** Throughput spikes to 185–219k ops/sec
   briefly (likely RocksDB compaction flush completing), then settles back.

3. **Steady-state throughput: ~177k ops/sec (5.6 us/op).** Stable with
   variance of ±8% around the mean.

4. **Write amplification equals read amplification** at steady state (~0.975).
   Characteristic of LVMT's AMT-based design.

5. **Average tree levels: 1.67.** Most keys resolved in 1–2 node accesses.
   The AMT fanout is very effective for 1M keys.

6. **Data writes constant at 200,000 per epoch** (100k read-then-write ops,
   2 data writes per op).

7. **No compaction stalls** — no sudden throughput drops beyond normal noise.

---

## Cross-Run Comparison

| Metric              | Run 1 (messy, prior session) | Run 2 (this file, clean) |
|---------------------|------------------------------|--------------------------|
| Process kills       | 4                            | 0                        |
| LOCK conflicts      | 2                            | 0                        |
| Terminal restarts   | ~6                           | 0                        |
| Final epoch         | 198                          | 198                      |
| Total time          | ~122.3 s                     | 118.8 s                  |
| Steady ops/sec      | ~175k                        | ~177k                    |
| Peak ops/sec        | ~194k                        | ~219k                    |
| Burst phase visible | No (weaker)                  | Yes (epochs 56–68)       |

**Conclusion:** Run 2 is ~3% faster and shows a clearer burst phase — likely
because the clean protocol avoided interference from leftover RocksDB state.
Results are reproducible across both runs.

---

## Lessons Learned This Session

1. **`main.rs` line 28 wipes `__benchmarks` before LOCK.** Running a second
   `cargo run` while the first is active silently destroys data — no crash,
   no error, just an empty snapshot. NEVER run two instances.

2. **`await_terminal` unreliable with redirected output.** Terminal appears idle
   when stdout goes to a file. Use `pgrep` monitoring in a separate terminal.

3. **`pgrep` monitor fails during compilation.** The `asb-main` process doesn't
   exist during `cargo build` — add a compilation delay before monitoring.
- `t07_lvmt_1m_time-plain_20260420.md` (re-run same experiment, different date)
