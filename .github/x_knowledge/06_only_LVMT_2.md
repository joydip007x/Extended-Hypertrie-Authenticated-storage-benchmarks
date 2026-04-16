# 06_only_LVMT_2 — Complete LVMT Batch Plan: ALL 103 Experiments

> **Prerequisite:** Read [07_MustRead.md](07_MustRead.md) before executing any step.
> Follow STEP -1 (sudo), STEP 0 (gate check), and batch execution pattern exactly.
> Individual command details are in [06_only_LVMT_1.md](06_only_LVMT_1.md).

---

## Goal

Reproduce the **complete LVMT evaluation** from the OSDI'23 paper:
- **42 warmups** (w00–w41)
- **46 time benchmarks** (t00–t45)
- **15 stat benchmarks** (s00–s14)
- **= 103 experiments total**

Organized into **13 named batches** by key size, so the user can say
"run Batch 1M" and the agent knows exactly which experiments to execute.

---

## Three Benchmark Types — Quick Reference

| Type | CLI Differences | cgroup? | Purpose |
|------|----------------|---------|---------|
| **Warmup** | `--warmup-to ./warmup/v4 --no-stat` | NO | Write all keys once → save snapshot |
| **Time** | `--no-stat --cache-size 2048` | YES (8 GB) | Measure throughput (ops/sec) under memory pressure |
| **Stat** | `--cache-size 8192` (no `--no-stat`) | NO | Measure read/write amplification with full cache |

All benchmarks use: `-a lvmt`, `--max-time 5400`, `--max-epoch 200`,
output to `./paper_experiment/osdi23/`.

**Warmups** create `./warmup/v4/<dir>/`. **Time + stat** consume those snapshots
via `--warmup-from ./warmup/v4`. Fresh experiments use `--no-warmup -k 10g`.
Real-trace experiments use `--real-trace --report-epoch 25`.

---

## Complete Parameter Audit

Every CLI parameter from `asb-options/src/lib.rs`, classified:

### Parameters VARIED in this batch

| Parameter | CLI Flag | Values | Effect |
|-----------|----------|--------|--------|
| **Key count** | `-k` | 1m, 1600k, 2500k, 4m, 6300k, 10m, 16m, 25m, 40m, 63m, 100m | Total unique keys in DB |
| **Shards** | `--shards N` | plain (none), 64, 16, 1 | AMT version tree depth |
| **Fresh** | `--no-warmup -k 10g` | yes/no | Start from empty DB |
| **Real trace** | `--real-trace` | yes/no | Replay production access pattern |
| **Bench type** | `--no-stat` / `--cache-size` | time vs stat | See table above |

### Parameters FIXED across ALL experiments

| Parameter | CLI Flag | Fixed Value | Notes |
|-----------|----------|-------------|-------|
| Algorithm | `-a` | `lvmt` | This is LVMT-only plan |
| Backend | `-b` | `rocksdb` (default) | Paper uses only rocksdb |
| Seed | `--seed` | 64 (default) | Fixed for reproducibility |
| Epoch size | `--epoch-size` | 50,000 (default) | 100k ops/epoch (50k R + 50k W) |
| Max time | `--max-time` | 5400 | 90-minute wall cap |
| Max epoch | `--max-epoch` | 200 | Epoch cap |
| Report interval | `--report-epoch` | 2 (default, 25 for real) | |
| DB dir | `--db` | `./__benchmarks` | Always wiped between runs |

---

## Master Experiment Matrix

### All 46 Time Benchmarks

| Key | plain | s64 | s16 | s1 |
|-----|-------|-----|-----|----|
| fresh | t00 | t01 | t02 | t03 |
| real | t04 | t05 | t06 | — |
| 1m | t07 | t08 | t09 | t10 |
| 1600k | t11 | t12 | t13 | t14 |
| 2500k | t15 | t16 | t17 | t18 |
| 4m | t19 | t20 | t21 | t22 |
| 6300k | t23 | t24 | t25 | t26 |
| 10m | t27 | t28 | t29 | t30 |
| 16m | t31 | t32 | t33 | — |
| 25m | t34 | t35 | t36 | — |
| 40m | t37 | t38 | t39 | — |
| 63m | t40 | t41 | t42 | — |
| 100m | t43 | t44 | t45 | — |

### All 15 Stat Benchmarks (only 5 key sizes, no s1)

| Key | plain | s64 | s16 |
|-----|-------|-----|-----|
| fresh | s00 | s01 | s02 |
| real | s03 | s04 | s05 |
| 1m | s06 | s07 | s08 |
| 10m | s09 | s10 | s11 |
| 100m | s12 | s13 | s14 |

### All 42 Warmups (one per unique key×shard that needs pre-population)

| Key | plain | s64 | s16 | s1 |
|-----|-------|-----|-----|----|
| real | w00 | w01 | w02 | — |
| 1m | w03 | w04 | w05 | w06 |
| 1600k | w07 | w08 | w09 | w10 |
| 2500k | w11 | w12 | w13 | w14 |
| 4m | w15 | w16 | w17 | w18 |
| 6300k | w19 | w20 | w21 | w22 |
| 10m | w23 | w24 | w25 | w26 |
| 16m | w27 | w28 | w29 | — |
| 25m | w30 | w31 | w32 | — |
| 40m | w33 | w34 | w35 | — |
| 63m | w36 | w37 | w38 | — |
| 100m | w39 | w40 | w41 | — |

---

## The 13 Batches

| Batch Name | Warmups | Time | Stat | Total | Est. Duration |
|------------|---------|------|------|-------|---------------|
| **FRESH** | 0 | 4 | 3 | **7** | 6–12 h |
| **REAL** | 3 | 3 | 3 | **9** | 6–12 h |
| **1M** | 4 | 4 | 3 | **11** | 1–3 h |
| **1600K** | 4 | 4 | 0 | **8** | 1–3 h |
| **2500K** | 4 | 4 | 0 | **8** | 2–4 h |
| **4M** | 4 | 4 | 0 | **8** | 3–5 h |
| **6300K** | 4 | 4 | 0 | **8** | 4–6 h |
| **10M** | 4 | 4 | 3 | **11** | 6–12 h |
| **16M** | 3 | 3 | 0 | **6** | 4–6 h |
| **25M** | 3 | 3 | 0 | **6** | 5–8 h |
| **40M** | 3 | 3 | 0 | **6** | 7–10 h |
| **63M** | 3 | 3 | 0 | **6** | 8–12 h |
| **100M** | 3 | 3 | 3 | **9** | 10–18 h |
| **TOTAL** | **42** | **46** | **15** | **103** | |

---

## Between-Experiment Protocol (EVERY transition)

```
1. Confirm previous exited:    pgrep -c asb-main → must be 0
2. Read + verify previous log: tail -3 FILE, grep -ci 'panic|error' FILE → 0
3. Wipe working dir:           rm -rf __benchmarks
4. IF time bench next:         sudo -n sysctl -w vm.drop_caches=3
                               echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
5. IF warmup or stat next:     no cgroup, no drop_caches
6. Run next experiment
```

---

## Batch FRESH — 7 experiments (0 warmups)

**Contents:** t00–t03 (4 time) + s00–s02 (3 stat)
**Warmup needed:** NONE — these use `--no-warmup -k 10g` (empty DB start)

### Time benchmarks (run inside cgroup)

```bash
# t00: fresh, plain
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --no-warmup -k 10g --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_fresh.log 2>&1

# t01: fresh, s64
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --no-warmup -k 10g --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_fresh.log 2>&1

# t02: fresh, s16
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --no-warmup -k 10g --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_fresh.log 2>&1

# t03: fresh, s1
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --no-warmup -k 10g --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_fresh.log 2>&1
```

### Stat benchmarks (NO cgroup, NO drop_caches)

```bash
# s00: fresh, plain
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --no-warmup -k 10g --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_fresh.log 2>&1

# s01: fresh, s64
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --no-warmup -k 10g --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_fresh.log 2>&1

# s02: fresh, s16
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --no-warmup -k 10g --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_fresh.log 2>&1
```

---

## Batch REAL — 9 experiments (3 warmups + 3 time + 3 stat)

**Contents:** w00–w02, t04–t06, s03–s05
**Special:** uses `--real-trace --report-epoch 25` instead of `-k` + `--report-epoch 2`

### Warmups (no cgroup, no drop_caches)

```bash
# w00: real, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 --real-trace -a lvmt \
  > /tmp/warmup_w00.log 2>&1

# w01: real, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 --real-trace -a lvmt --shards 64 \
  > /tmp/warmup_w01.log 2>&1

# w02: real, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 --real-trace -a lvmt --shards 16 \
  > /tmp/warmup_w02.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t04: real, plain (requires w00)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_real.log 2>&1

# t05: real, s64 (requires w01)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_real.log 2>&1

# t06: real, s16 (requires w02)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_real.log 2>&1
```

### Stat benchmarks (no cgroup)

```bash
# s03: real, plain (requires w00)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_real.log 2>&1

# s04: real, s64 (requires w01)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_real.log 2>&1

# s05: real, s16 (requires w02)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_real.log 2>&1
```

---

## Batch 1M — 11 experiments (4 warmups + 4 time + 3 stat)

**Note:** Stat has only 3 experiments (plain, s64, s16 — no s1 in stat)

### Warmups

```bash
# w03: 1m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt > /tmp/warmup_w03.log 2>&1
# w04: 1m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 64 > /tmp/warmup_w04.log 2>&1
# w05: 1m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 16 > /tmp/warmup_w05.log 2>&1
# w06: 1m, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 1 > /tmp/warmup_w06.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t07: 1m, plain (requires w03)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_1m.log 2>&1

# t08: 1m, s64 (requires w04)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_1m.log 2>&1

# t09: 1m, s16 (requires w05)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_1m.log 2>&1

# t10: 1m, s1 (requires w06)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_1m.log 2>&1
```

### Stat benchmarks (no cgroup, no s1)

```bash
# s06: 1m, plain (requires w03)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_1m.log 2>&1

# s07: 1m, s64 (requires w04)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_1m.log 2>&1

# s08: 1m, s16 (requires w05)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_1m.log 2>&1
```

---

## Batch 1600K — 8 experiments (4 warmups + 4 time, no stat)

### Warmups

```bash
# w07: 1600k, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1600k -a lvmt > /tmp/warmup_w07.log 2>&1
# w08: 1600k, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1600k -a lvmt --shards 64 > /tmp/warmup_w08.log 2>&1
# w09: 1600k, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1600k -a lvmt --shards 16 > /tmp/warmup_w09.log 2>&1
# w10: 1600k, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1600k -a lvmt --shards 1 > /tmp/warmup_w10.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t11: 1600k, plain (requires w07)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1600k --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_1600k.log 2>&1

# t12: 1600k, s64 (requires w08)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1600k --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_1600k.log 2>&1

# t13: 1600k, s16 (requires w09)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1600k --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_1600k.log 2>&1

# t14: 1600k, s1 (requires w10)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1600k --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_1600k.log 2>&1
```

---

## Batch 2500K — 8 experiments (4 warmups + 4 time, no stat)

### Warmups

```bash
# w11: 2500k, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 2500k -a lvmt > /tmp/warmup_w11.log 2>&1
# w12: 2500k, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 2500k -a lvmt --shards 64 > /tmp/warmup_w12.log 2>&1
# w13: 2500k, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 2500k -a lvmt --shards 16 > /tmp/warmup_w13.log 2>&1
# w14: 2500k, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 2500k -a lvmt --shards 1 > /tmp/warmup_w14.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t15: 2500k, plain (requires w11)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 2500k --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_2500k.log 2>&1

# t16: 2500k, s64 (requires w12)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 2500k --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_2500k.log 2>&1

# t17: 2500k, s16 (requires w13)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 2500k --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_2500k.log 2>&1

# t18: 2500k, s1 (requires w14)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 2500k --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_2500k.log 2>&1
```

---

## Batch 4M — 8 experiments (4 warmups + 4 time, no stat)

### Warmups

```bash
# w15: 4m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 4m -a lvmt > /tmp/warmup_w15.log 2>&1
# w16: 4m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 4m -a lvmt --shards 64 > /tmp/warmup_w16.log 2>&1
# w17: 4m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 4m -a lvmt --shards 16 > /tmp/warmup_w17.log 2>&1
# w18: 4m, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 4m -a lvmt --shards 1 > /tmp/warmup_w18.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t19: 4m, plain (requires w15)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 4m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_4m.log 2>&1

# t20: 4m, s64 (requires w16)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 4m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_4m.log 2>&1

# t21: 4m, s16 (requires w17)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 4m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_4m.log 2>&1

# t22: 4m, s1 (requires w18)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 4m --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_4m.log 2>&1
```

---

## Batch 6300K — 8 experiments (4 warmups + 4 time, no stat)

### Warmups

```bash
# w19: 6300k, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 6300k -a lvmt > /tmp/warmup_w19.log 2>&1
# w20: 6300k, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 6300k -a lvmt --shards 64 > /tmp/warmup_w20.log 2>&1
# w21: 6300k, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 6300k -a lvmt --shards 16 > /tmp/warmup_w21.log 2>&1
# w22: 6300k, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 6300k -a lvmt --shards 1 > /tmp/warmup_w22.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t23: 6300k, plain (requires w19)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 6300k --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_6300k.log 2>&1

# t24: 6300k, s64 (requires w20)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 6300k --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_6300k.log 2>&1

# t25: 6300k, s16 (requires w21)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 6300k --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_6300k.log 2>&1

# t26: 6300k, s1 (requires w22)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 6300k --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_6300k.log 2>&1
```

---

## Batch 10M — 11 experiments (4 warmups + 4 time + 3 stat)

### Warmups

```bash
# w23: 10m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 10m -a lvmt > /tmp/warmup_w23.log 2>&1
# w24: 10m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 10m -a lvmt --shards 64 > /tmp/warmup_w24.log 2>&1
# w25: 10m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 10m -a lvmt --shards 16 > /tmp/warmup_w25.log 2>&1
# w26: 10m, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 10m -a lvmt --shards 1 > /tmp/warmup_w26.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t27: 10m, plain (requires w23)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_10m.log 2>&1

# t28: 10m, s64 (requires w24)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_10m.log 2>&1

# t29: 10m, s16 (requires w25)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_10m.log 2>&1

# t30: 10m, s1 (requires w26)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_10m.log 2>&1
```

### Stat benchmarks (no cgroup, no s1)

```bash
# s09: 10m, plain (requires w23)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_10m.log 2>&1

# s10: 10m, s64 (requires w24)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_10m.log 2>&1

# s11: 10m, s16 (requires w25)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_10m.log 2>&1
```

---

## Batch 16M — 6 experiments (3 warmups + 3 time, no stat, no s1)

> s1 excluded at ≥16m — would exceed memory/time limits.

### Warmups

```bash
# w27: 16m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 16m -a lvmt > /tmp/warmup_w27.log 2>&1
# w28: 16m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 16m -a lvmt --shards 64 > /tmp/warmup_w28.log 2>&1
# w29: 16m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 16m -a lvmt --shards 16 > /tmp/warmup_w29.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t31: 16m, plain (requires w27)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 16m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_16m.log 2>&1

# t32: 16m, s64 (requires w28)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 16m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_16m.log 2>&1

# t33: 16m, s16 (requires w29)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 16m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_16m.log 2>&1
```

---

## Batch 25M — 6 experiments (3 warmups + 3 time, no stat, no s1)

### Warmups

```bash
# w30: 25m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 25m -a lvmt > /tmp/warmup_w30.log 2>&1
# w31: 25m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 25m -a lvmt --shards 64 > /tmp/warmup_w31.log 2>&1
# w32: 25m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 25m -a lvmt --shards 16 > /tmp/warmup_w32.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t34: 25m, plain (requires w30)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 25m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_25m.log 2>&1

# t35: 25m, s64 (requires w31)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 25m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_25m.log 2>&1

# t36: 25m, s16 (requires w32)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 25m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_25m.log 2>&1
```

---

## Batch 40M — 6 experiments (3 warmups + 3 time, no stat, no s1)

### Warmups

```bash
# w33: 40m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 40m -a lvmt > /tmp/warmup_w33.log 2>&1
# w34: 40m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 40m -a lvmt --shards 64 > /tmp/warmup_w34.log 2>&1
# w35: 40m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 40m -a lvmt --shards 16 > /tmp/warmup_w35.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t37: 40m, plain (requires w33)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 40m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_40m.log 2>&1

# t38: 40m, s64 (requires w34)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 40m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_40m.log 2>&1

# t39: 40m, s16 (requires w35)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 40m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_40m.log 2>&1
```

---

## Batch 63M — 6 experiments (3 warmups + 3 time, no stat, no s1)

### Warmups

```bash
# w36: 63m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 63m -a lvmt > /tmp/warmup_w36.log 2>&1
# w37: 63m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 63m -a lvmt --shards 64 > /tmp/warmup_w37.log 2>&1
# w38: 63m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 63m -a lvmt --shards 16 > /tmp/warmup_w38.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t40: 63m, plain (requires w36)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 63m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_63m.log 2>&1

# t41: 63m, s64 (requires w37)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 63m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_63m.log 2>&1

# t42: 63m, s16 (requires w38)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 63m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_63m.log 2>&1
```

---

## Batch 100M — 9 experiments (3 warmups + 3 time + 3 stat, no s1)

> **Disk:** warmups need ~30–90 GB, check `df -h .` first.

### Warmups

```bash
# w39: 100m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 100m -a lvmt > /tmp/warmup_w39.log 2>&1
# w40: 100m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 100m -a lvmt --shards 64 > /tmp/warmup_w40.log 2>&1
# w41: 100m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 100m -a lvmt --shards 16 > /tmp/warmup_w41.log 2>&1
```

### Time benchmarks (cgroup)

```bash
# t43: 100m, plain (requires w39)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_100m.log 2>&1

# t44: 100m, s64 (requires w40)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_100m.log 2>&1

# t45: 100m, s16 (requires w41)
sudo -n sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
echo $$ | sudo -n tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_100m.log 2>&1
```

### Stat benchmarks (no cgroup, no s1)

```bash
# s12: 100m, plain (requires w39)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_100m.log 2>&1

# s13: 100m, s64 (requires w40)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_100m.log 2>&1

# s14: 100m, s16 (requires w41)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_100m.log 2>&1
```

---

## Quick-Reference: "Run Batch X" Cheat Sheet

When the user says **"run Batch 1M"**, the agent does:

1. `bash fix_env.sh` (automated sudo + cgroup + env check)
2. Gate check (STEP 0)
3. Run w03, w04, w05, w06 sequentially (warmups)
4. Verify 4 warmup snapshots: `ls ./warmup/v4/ | grep -i lvmt.*1e6`
5. Run t07, t08, t09, t10 sequentially (time, with cgroup + drop_caches between each)
6. Run s06, s07, s08 sequentially (stat, no cgroup)
7. Verify all 7 logs in `./paper_experiment/osdi23/`
8. Create y_runs analytics for each

**Order within a batch:** always warmups first → time benchmarks → stat benchmarks.
Between each experiment: follow the Between-Experiment Protocol above.

---

## Execution Notes for the Agent

1. **Warmups are cheap, benchmarks are expensive.** Run ALL warmups for a batch first,
   then ALL time benchmarks, then ALL stat benchmarks. If a benchmark fails, the warmups
   don't need to be re-done.

2. **Stat benchmarks reuse the SAME warmup snapshots as time benchmarks.** w03 serves
   both t07 and s06. No separate stat warmups needed.

3. **Shared warmups across batches:** If Batch 1M warmups are done (w03–w06 exist),
   running Batch 1M again only needs steps 5–8 (skip warmups).

4. **Check disk before large batches:** `df -h .` — 10M needs ~4–12 GB,
   100M needs ~30–90 GB for warmup snapshots alone.

5. **s1 shard excluded at ≥16m keys.** The matrices above show this — don't try to
   run s1 experiments for 16m/25m/40m/63m/100m.

6. **Fresh experiments (Batch FRESH) use `-k 10g --no-warmup`.** This means "infinitely
   many keys" — the DB starts empty and grows.

7. **Real-trace experiments (Batch REAL) use `--real-trace --report-epoch 25`.**
   No `-k` flag. The trace file is at `./trace/real_trace.init`.

8. **Warmup logs go to `/tmp/warmup_wNN.log`.** Not worth saving long-term.
   Time/stat logs go to `./paper_experiment/osdi23/` — these are the final results.

---

## Already Completed

> **All marks cleared for fresh start.** Previous results exist in `.github/y_runs/`
> and `hand_off/session_2026-04-15.md` for reference.

| ID | Status | Notes |
|----|--------|-------|
| — | — | No experiments marked complete — start any batch fresh |
