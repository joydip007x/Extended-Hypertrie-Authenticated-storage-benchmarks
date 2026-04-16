# 06 — LVMT-Only Experiment Reference

## Summary

**103 experiments total** for LVMT (the OSDI'23 paper's main contribution):

| Phase   | IDs                  | Count | Purpose                          |
|---------|----------------------|-------|----------------------------------|
| Warmup  | `only-lvmt-w00`–`w41` | 42    | Populate DB, save for reuse      |
| Time    | `only-lvmt-t00`–`t45` | 46    | Throughput (ops/sec), 8 GB limit |
| Stat    | `only-lvmt-s00`–`s14` | 15    | I/O amplification metrics        |

Each experiment can be run **individually** (see [Commands](#individual-commands) below).  
Non-fresh benchmarks require their matching warmup to have completed first.

---

## What Is LVMT?

LVMT = Logged Versioned Merkle Trie.  
Uses an Algebraic Merkle Tree (AMT) with multi-layer versioning for authenticated storage.

### Shard Variants

`--shards N` restricts the version tree to a subtree at depth `log₂(N)`:

| Variant | CLI Flag       | Tree Depth | Meaning                    |
|---------|----------------|------------|----------------------------|
| plain   | *(none)*       | full       | Complete tree, no sharding |
| s64     | `--shards 64`  | 6          | 64 independent shards      |
| s16     | `--shards 16`  | 4          | 16 independent shards      |
| s1      | `--shards 1`   | 0          | Single shard (depth 0)     |

> **Note:** `s1` is excluded from large key counts (≥16 m) and real traces because it would hit memory/time limits.

### Key Sizes

| Key Param | Total Keys      | Scientific | Warmup Epochs (~) |
|-----------|----------------|------------|-------------------|
| real      | Ethereum trace | `real`     | varies            |
| 1m        | 1,000,000      | `1e6`      | 20                |
| 1600k     | 1,600,000      | `1.6e6`    | 32                |
| 2500k     | 2,500,000      | `2.5e6`    | 50                |
| 4m        | 4,000,000      | `4e6`      | 80                |
| 6300k     | 6,300,000      | `6.3e6`    | 126               |
| 10m       | 10,000,000     | `1e7`      | 200               |
| 16m       | 16,000,000     | `1.6e7`    | 320               |
| 25m       | 25,000,000     | `2.5e7`    | 500               |
| 40m       | 40,000,000     | `4e7`      | 800               |
| 63m       | 63,000,000     | `6.3e7`    | 1,260             |
| 100m      | 100,000,000    | `1e8`      | 2,000             |
| 10g       | 10,000,000,000 | `1e10`     | N/A (fresh only)  |

Warmup epochs = `total_keys / epoch_size` where `epoch_size = 50,000`.

---

## Phase Descriptions

### Warmup (W-series)

- Writes all keys to DB once (single pass), then saves snapshot to `./warmup/v4/<dir>/`.
- Binary exits automatically after save (`return` in `run_tasks` when `--warmup-to` is set).
- No timing measurement. No cgroup.
- **Required before** any T/S run with matching key + shard variant.

### Time Benchmark (T-series)

- Measures **throughput** (ops/sec).
- `--no-stat` → backend statistics disabled for accurate timing.
- Runs inside **8 GB cgroup** via `./cgrun.sh`.
- `sudo sysctl -w vm.drop_caches=3` before each run.
- `--cache-size 2048` (2 GB RocksDB block cache).
- Stops at **min(5400 s, 200 epochs)** for keyed workloads; **5400 s** for real/fresh.
- Each epoch = 50,000 random read-then-write pairs (100k ops/epoch).

### Stat Benchmark (S-series)

- Measures **read/write amplification** (backend I/O divided by logical I/O).
- Backend statistics **enabled** (no `--no-stat` flag).
- **No cgroup** memory limit.
- `--cache-size 8192` (8 GB RocksDB block cache).
- Same stop conditions as time bench.
- Only 5 key sizes tested: fresh, real, 1m, 10m, 100m.
- Only 2 shard variants: s64, s16 (no s1).

---

## Prerequisites

```bash
export PATH="$HOME/.cargo/bin:$PATH"
export CXXFLAGS="-Wno-error -include cstdint"
cargo build --release          # must build first
mkdir -p ./warmup/v4
mkdir -p ./paper_experiment/osdi23
```

For time benchmarks: `./cgrun.sh` and cgroup must be configured (see `01_environment.md`).

---

## Warmup Reuse — Build Once, Use Many Times

### Yes, This Is Already Correctly Set Up

The warmup phase is **designed** to be run once and reused across multiple benchmarks.
You do NOT need to re-warmup for each experiment. Here's how it works:

1. **Warmup creates a DB snapshot** → saved as a directory under `./warmup/v4/<name>/`
2. **Each benchmark copies that snapshot** into `__benchmarks/` at startup (`--warmup-from`)
3. **The original snapshot is never modified** — the benchmark works on its own copy

So one warmup serves as a read-only template for all subsequent benchmarks that share its
key size + shard configuration.

### How the Code Proves This

In `benchmarks/src/run.rs`:
```
// Benchmark COPIES from warmup dir → __benchmarks/ (content_only = true)
if let Some(ref warmup_dir) = options.warmup_from() {
    fs_extra::dir::copy(warmup_dir, db_dir, &options).unwrap();
}
```
The warmup snapshot is **copied** (not moved, not modified). It stays intact for the next run.

### Concrete Reuse Map

Each warmup snapshot below is used by **multiple** experiments (time + stat):

| Warmup | Snapshot Dir     | Used By                | Reuse Count |
|--------|------------------|------------------------|-------------|
| w00    | `LVMT_real/`     | t04, s03               | 2           |
| w01    | `LVMT64_real/`   | t05, s04               | 2           |
| w02    | `LVMT16_real/`   | t06, s05               | 2           |
| w03    | `LVMT_1e6/`      | t07, s06               | 2           |
| w04    | `LVMT64_1e6/`    | t08, s07               | 2           |
| w05    | `LVMT16_1e6/`    | t09, s08               | 2           |
| w06    | `LVMT1_1e6/`     | t10                    | 1           |
| w07    | `LVMT_1.6e6/`    | t11                    | 1           |
| w08    | `LVMT64_1.6e6/`  | t12                    | 1           |
| w09    | `LVMT16_1.6e6/`  | t13                    | 1           |
| w10    | `LVMT1_1.6e6/`   | t14                    | 1           |
| w11    | `LVMT_2.5e6/`    | t15                    | 1           |
| w12    | `LVMT64_2.5e6/`  | t16                    | 1           |
| w13    | `LVMT16_2.5e6/`  | t17                    | 1           |
| w14    | `LVMT1_2.5e6/`   | t18                    | 1           |
| w15    | `LVMT_4e6/`      | t19                    | 1           |
| w16    | `LVMT64_4e6/`    | t20                    | 1           |
| w17    | `LVMT16_4e6/`    | t21                    | 1           |
| w18    | `LVMT1_4e6/`     | t22                    | 1           |
| w19    | `LVMT_6.3e6/`    | t23                    | 1           |
| w20    | `LVMT64_6.3e6/`  | t24                    | 1           |
| w21    | `LVMT16_6.3e6/`  | t25                    | 1           |
| w22    | `LVMT1_6.3e6/`   | t26                    | 1           |
| w23    | `LVMT_1e7/`      | t27, s09               | 2           |
| w24    | `LVMT64_1e7/`    | t28, s10               | 2           |
| w25    | `LVMT16_1e7/`    | t29, s11               | 2           |
| w26    | `LVMT1_1e7/`     | t30                    | 1           |
| w27    | `LVMT_1.6e7/`    | t31                    | 1           |
| w28    | `LVMT64_1.6e7/`  | t32                    | 1           |
| w29    | `LVMT16_1.6e7/`  | t33                    | 1           |
| w30    | `LVMT_2.5e7/`    | t34                    | 1           |
| w31    | `LVMT64_2.5e7/`  | t35                    | 1           |
| w32    | `LVMT16_2.5e7/`  | t36                    | 1           |
| w33    | `LVMT_4e7/`      | t37                    | 1           |
| w34    | `LVMT64_4e7/`    | t38                    | 1           |
| w35    | `LVMT16_4e7/`    | t39                    | 1           |
| w36    | `LVMT_6.3e7/`    | t40                    | 1           |
| w37    | `LVMT64_6.3e7/`  | t41                    | 1           |
| w38    | `LVMT16_6.3e7/`  | t42                    | 1           |
| w39    | `LVMT_1e8/`      | t43, s12               | 2           |
| w40    | `LVMT64_1e8/`    | t44, s13               | 2           |
| w41    | `LVMT16_1e8/`    | t45, s14               | 2           |

- **12 warmups** serve **2 experiments** each (both time + stat benchmarks share them)
- **30 warmups** serve **1 experiment** each (time-only key sizes with no stat counterpart)
- **4 fresh experiments** (t00–t03, s00–s02) need **zero warmups** (start empty)

### Example: One Warmup → Multiple Benchmarks

Running `only-lvmt-w03` (1m, plain LVMT) creates `./warmup/v4/LVMT_1e6/`.
That single snapshot is then reused by:

```
only-lvmt-t07  →  time bench, 1m, plain   (copies LVMT_1e6/ → __benchmarks/, runs, deletes __benchmarks/)
only-lvmt-s06  →  stat bench, 1m, plain   (copies LVMT_1e6/ → __benchmarks/, runs, deletes __benchmarks/)
```

The snapshot `LVMT_1e6/` is **never touched** — you can run t07 and s06 in any order,
repeat them, or run them days apart. As long as `./warmup/v4/LVMT_1e6/` exists, it works.

### Practical Workflow for Running 5–10 Experiments Efficiently

**Step 1:** Run only the warmups you need (once):
```bash
# Prepare warmups for 1m (all 4 shard variants) — ~4–12 min total
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 1
```

**Step 2:** Verify snapshots exist:
```bash
ls ./warmup/v4/ | grep LVMT
# Should show: LVMT_1e6/  LVMT64_1e6/  LVMT16_1e6/  LVMT1_1e6/
```

**Step 3:** Run any combination of benchmarks against those warmups — in any order, any time:
```bash
# Time benchmarks (4 runs, ~20–60 min total)
# only-lvmt-t07  plain
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_1m.log

# only-lvmt-t08  s64
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_1m.log

# ... t09 (s16), t10 (s1) follow same pattern

# Stat benchmarks (3 runs — no s1 in stat phase, ~15–45 min total)
# only-lvmt-s06  plain
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_1m.log

# only-lvmt-s07  s64
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_1m.log

# only-lvmt-s08  s16
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_1m.log
```

**Result:** 4 warmups → 7 benchmarks. Warmup cost paid once (~4–12 min), benchmarks reuse freely.

### What About Re-Running a Failed Experiment?

Just re-run it. The warmup snapshot is untouched. Each benchmark starts by:
1. `rm -rf __benchmarks` — wipe previous working copy
2. Copy snapshot → `__benchmarks/` — fresh copy from warmup
3. Run benchmark on the copy

If a time benchmark crashes or you kill it, the warmup is still safe. Just re-run.

### Disk Space Warning

Each warmup snapshot takes disk space proportional to the key count:
- 1m keys: ~100–300 MB per snapshot
- 10m keys: ~1–3 GB per snapshot
- 100m keys: ~10–30 GB per snapshot

All 42 warmup snapshots together may use **50–200 GB** of disk under `./warmup/v4/`.
You can delete individual warmup dirs after their benchmarks complete to reclaim space.

---

## Experiment Tables

### Warmup (W00–W41)

| ID  | Key    | Shards | Warmup Dir         | Est. Time   |
|-----|--------|--------|--------------------|-------------|
| w00 | real   | plain  | `LVMT_real/`       | 5–20 min    |
| w01 | real   | 64     | `LVMT64_real/`     | 5–20 min    |
| w02 | real   | 16     | `LVMT16_real/`     | 5–20 min    |
| w03 | 1m     | plain  | `LVMT_1e6/`        | 1–3 min     |
| w04 | 1m     | 64     | `LVMT64_1e6/`      | 1–3 min     |
| w05 | 1m     | 16     | `LVMT16_1e6/`      | 1–3 min     |
| w06 | 1m     | 1      | `LVMT1_1e6/`       | 1–3 min     |
| w07 | 1600k  | plain  | `LVMT_1.6e6/`      | 2–5 min     |
| w08 | 1600k  | 64     | `LVMT64_1.6e6/`    | 2–5 min     |
| w09 | 1600k  | 16     | `LVMT16_1.6e6/`    | 2–5 min     |
| w10 | 1600k  | 1      | `LVMT1_1.6e6/`     | 2–5 min     |
| w11 | 2500k  | plain  | `LVMT_2.5e6/`      | 3–6 min     |
| w12 | 2500k  | 64     | `LVMT64_2.5e6/`    | 3–6 min     |
| w13 | 2500k  | 16     | `LVMT16_2.5e6/`    | 3–6 min     |
| w14 | 2500k  | 1      | `LVMT1_2.5e6/`     | 3–6 min     |
| w15 | 4m     | plain  | `LVMT_4e6/`        | 5–12 min    |
| w16 | 4m     | 64     | `LVMT64_4e6/`      | 5–12 min    |
| w17 | 4m     | 16     | `LVMT16_4e6/`      | 5–12 min    |
| w18 | 4m     | 1      | `LVMT1_4e6/`       | 5–12 min    |
| w19 | 6300k  | plain  | `LVMT_6.3e6/`      | 8–18 min    |
| w20 | 6300k  | 64     | `LVMT64_6.3e6/`    | 8–18 min    |
| w21 | 6300k  | 16     | `LVMT16_6.3e6/`    | 8–18 min    |
| w22 | 6300k  | 1      | `LVMT1_6.3e6/`     | 8–18 min    |
| w23 | 10m    | plain  | `LVMT_1e7/`        | 12–30 min   |
| w24 | 10m    | 64     | `LVMT64_1e7/`      | 12–30 min   |
| w25 | 10m    | 16     | `LVMT16_1e7/`      | 12–30 min   |
| w26 | 10m    | 1      | `LVMT1_1e7/`       | 12–30 min   |
| w27 | 16m    | plain  | `LVMT_1.6e7/`      | 20–45 min   |
| w28 | 16m    | 64     | `LVMT64_1.6e7/`    | 20–45 min   |
| w29 | 16m    | 16     | `LVMT16_1.6e7/`    | 20–45 min   |
| w30 | 25m    | plain  | `LVMT_2.5e7/`      | 30–70 min   |
| w31 | 25m    | 64     | `LVMT64_2.5e7/`    | 30–70 min   |
| w32 | 25m    | 16     | `LVMT16_2.5e7/`    | 30–70 min   |
| w33 | 40m    | plain  | `LVMT_4e7/`        | 50–100 min  |
| w34 | 40m    | 64     | `LVMT64_4e7/`      | 50–100 min  |
| w35 | 40m    | 16     | `LVMT16_4e7/`      | 50–100 min  |
| w36 | 63m    | plain  | `LVMT_6.3e7/`      | 70–140 min  |
| w37 | 63m    | 64     | `LVMT64_6.3e7/`    | 70–140 min  |
| w38 | 63m    | 16     | `LVMT16_6.3e7/`    | 70–140 min  |
| w39 | 100m   | plain  | `LVMT_1e8/`        | 90–180 min  |
| w40 | 100m   | 64     | `LVMT64_1e8/`      | 90–180 min  |
| w41 | 100m   | 16     | `LVMT16_1e8/`      | 90–180 min  |

All warmup dirs are under `./warmup/v4/`.

### Time Benchmarks (T00–T45)

| ID  | Key    | Shards | Requires | Output File               | Est. Time  |
|-----|--------|--------|----------|---------------------------|------------|
| t00 | fresh  | plain  | —        | `time_lvmt_fresh.log`     | ~90 min    |
| t01 | fresh  | 64     | —        | `time_lvmt64_fresh.log`   | ~90 min    |
| t02 | fresh  | 16     | —        | `time_lvmt16_fresh.log`   | ~90 min    |
| t03 | fresh  | 1      | —        | `time_lvmt1_fresh.log`    | ~90 min    |
| t04 | real   | plain  | w00      | `time_lvmt_real.log`      | ~90 min    |
| t05 | real   | 64     | w01      | `time_lvmt64_real.log`    | ~90 min    |
| t06 | real   | 16     | w02      | `time_lvmt16_real.log`    | ~90 min    |
| t07 | 1m     | plain  | w03      | `time_lvmt_1m.log`        | 5–15 min   |
| t08 | 1m     | 64     | w04      | `time_lvmt64_1m.log`      | 5–15 min   |
| t09 | 1m     | 16     | w05      | `time_lvmt16_1m.log`      | 5–15 min   |
| t10 | 1m     | 1      | w06      | `time_lvmt1_1m.log`       | 5–15 min   |
| t11 | 1600k  | plain  | w07      | `time_lvmt_1600k.log`     | 8–25 min   |
| t12 | 1600k  | 64     | w08      | `time_lvmt64_1600k.log`   | 8–25 min   |
| t13 | 1600k  | 16     | w09      | `time_lvmt16_1600k.log`   | 8–25 min   |
| t14 | 1600k  | 1      | w10      | `time_lvmt1_1600k.log`    | 8–25 min   |
| t15 | 2500k  | plain  | w11      | `time_lvmt_2500k.log`     | 12–35 min  |
| t16 | 2500k  | 64     | w12      | `time_lvmt64_2500k.log`   | 12–35 min  |
| t17 | 2500k  | 16     | w13      | `time_lvmt16_2500k.log`   | 12–35 min  |
| t18 | 2500k  | 1      | w14      | `time_lvmt1_2500k.log`    | 12–35 min  |
| t19 | 4m     | plain  | w15      | `time_lvmt_4m.log`        | 20–50 min  |
| t20 | 4m     | 64     | w16      | `time_lvmt64_4m.log`      | 20–50 min  |
| t21 | 4m     | 16     | w17      | `time_lvmt16_4m.log`      | 20–50 min  |
| t22 | 4m     | 1      | w18      | `time_lvmt1_4m.log`       | 20–50 min  |
| t23 | 6300k  | plain  | w19      | `time_lvmt_6300k.log`     | 25–65 min  |
| t24 | 6300k  | 64     | w20      | `time_lvmt64_6300k.log`   | 25–65 min  |
| t25 | 6300k  | 16     | w21      | `time_lvmt16_6300k.log`   | 25–65 min  |
| t26 | 6300k  | 1      | w22      | `time_lvmt1_6300k.log`    | 25–65 min  |
| t27 | 10m    | plain  | w23      | `time_lvmt_10m.log`       | 35–90 min  |
| t28 | 10m    | 64     | w24      | `time_lvmt64_10m.log`     | 35–90 min  |
| t29 | 10m    | 16     | w25      | `time_lvmt16_10m.log`     | 35–90 min  |
| t30 | 10m    | 1      | w26      | `time_lvmt1_10m.log`      | 35–90 min  |
| t31 | 16m    | plain  | w27      | `time_lvmt_16m.log`       | 50–90 min  |
| t32 | 16m    | 64     | w28      | `time_lvmt64_16m.log`     | 50–90 min  |
| t33 | 16m    | 16     | w29      | `time_lvmt16_16m.log`     | 50–90 min  |
| t34 | 25m    | plain  | w30      | `time_lvmt_25m.log`       | 60–90 min  |
| t35 | 25m    | 64     | w31      | `time_lvmt64_25m.log`     | 60–90 min  |
| t36 | 25m    | 16     | w32      | `time_lvmt16_25m.log`     | 60–90 min  |
| t37 | 40m    | plain  | w33      | `time_lvmt_40m.log`       | 70–90 min  |
| t38 | 40m    | 64     | w34      | `time_lvmt64_40m.log`     | 70–90 min  |
| t39 | 40m    | 16     | w35      | `time_lvmt16_40m.log`     | 70–90 min  |
| t40 | 63m    | plain  | w36      | `time_lvmt_63m.log`       | 80–90 min  |
| t41 | 63m    | 64     | w37      | `time_lvmt64_63m.log`     | 80–90 min  |
| t42 | 63m    | 16     | w38      | `time_lvmt16_63m.log`     | 80–90 min  |
| t43 | 100m   | plain  | w39      | `time_lvmt_100m.log`      | ~90 min    |
| t44 | 100m   | 64     | w40      | `time_lvmt64_100m.log`    | ~90 min    |
| t45 | 100m   | 16     | w41      | `time_lvmt16_100m.log`    | ~90 min    |

All output files are under `./paper_experiment/osdi23/`.

### Stat Benchmarks (S00–S14)

| ID  | Key    | Shards | Requires | Output File               | Est. Time  |
|-----|--------|--------|----------|---------------------------|------------|
| s00 | fresh  | plain  | —        | `stat_lvmt_fresh.log`     | ~90 min    |
| s01 | fresh  | 64     | —        | `stat_lvmt64_fresh.log`   | ~90 min    |
| s02 | fresh  | 16     | —        | `stat_lvmt16_fresh.log`   | ~90 min    |
| s03 | real   | plain  | w00      | `stat_lvmt_real.log`      | ~90 min    |
| s04 | real   | 64     | w01      | `stat_lvmt64_real.log`    | ~90 min    |
| s05 | real   | 16     | w02      | `stat_lvmt16_real.log`    | ~90 min    |
| s06 | 1m     | plain  | w03      | `stat_lvmt_1m.log`        | 5–15 min   |
| s07 | 1m     | 64     | w04      | `stat_lvmt64_1m.log`      | 5–15 min   |
| s08 | 1m     | 16     | w05      | `stat_lvmt16_1m.log`      | 5–15 min   |
| s09 | 10m    | plain  | w23      | `stat_lvmt_10m.log`       | 35–90 min  |
| s10 | 10m    | 64     | w24      | `stat_lvmt64_10m.log`     | 35–90 min  |
| s11 | 10m    | 16     | w25      | `stat_lvmt16_10m.log`     | 35–90 min  |
| s12 | 100m   | plain  | w39      | `stat_lvmt_100m.log`      | ~90 min    |
| s13 | 100m   | 64     | w40      | `stat_lvmt64_100m.log`    | ~90 min    |
| s14 | 100m   | 16     | w41      | `stat_lvmt16_100m.log`    | ~90 min    |

All output files are under `./paper_experiment/osdi23/`.

---

## Individual Commands

> **Environment** — every command below assumes:
> ```bash
> export PATH="$HOME/.cargo/bin:$PATH"
> export CXXFLAGS="-Wno-error -include cstdint"
> cd /home/q36dd/Desktop/Extended-Hypertrie-Authenticated-storage-benchmarks
> ```
> `cgrun.sh` already sets these, so time-bench commands need no extra setup.

### Warmup Commands (W00–W41)

```bash
# only-lvmt-w00  real, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 --real-trace -a lvmt

# only-lvmt-w01  real, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 --real-trace -a lvmt --shards 64

# only-lvmt-w02  real, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 --real-trace -a lvmt --shards 16

# only-lvmt-w03  1m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt

# only-lvmt-w04  1m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 64

# only-lvmt-w05  1m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 16

# only-lvmt-w06  1m, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards 1

# only-lvmt-w07  1600k, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1600k -a lvmt

# only-lvmt-w08  1600k, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1600k -a lvmt --shards 64

# only-lvmt-w09  1600k, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1600k -a lvmt --shards 16

# only-lvmt-w10  1600k, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1600k -a lvmt --shards 1

# only-lvmt-w11  2500k, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 2500k -a lvmt

# only-lvmt-w12  2500k, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 2500k -a lvmt --shards 64

# only-lvmt-w13  2500k, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 2500k -a lvmt --shards 16

# only-lvmt-w14  2500k, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 2500k -a lvmt --shards 1

# only-lvmt-w15  4m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 4m -a lvmt

# only-lvmt-w16  4m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 4m -a lvmt --shards 64

# only-lvmt-w17  4m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 4m -a lvmt --shards 16

# only-lvmt-w18  4m, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 4m -a lvmt --shards 1

# only-lvmt-w19  6300k, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 6300k -a lvmt

# only-lvmt-w20  6300k, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 6300k -a lvmt --shards 64

# only-lvmt-w21  6300k, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 6300k -a lvmt --shards 16

# only-lvmt-w22  6300k, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 6300k -a lvmt --shards 1

# only-lvmt-w23  10m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 10m -a lvmt

# only-lvmt-w24  10m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 10m -a lvmt --shards 64

# only-lvmt-w25  10m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 10m -a lvmt --shards 16

# only-lvmt-w26  10m, s1
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 10m -a lvmt --shards 1

# only-lvmt-w27  16m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 16m -a lvmt

# only-lvmt-w28  16m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 16m -a lvmt --shards 64

# only-lvmt-w29  16m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 16m -a lvmt --shards 16

# only-lvmt-w30  25m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 25m -a lvmt

# only-lvmt-w31  25m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 25m -a lvmt --shards 64

# only-lvmt-w32  25m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 25m -a lvmt --shards 16

# only-lvmt-w33  40m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 40m -a lvmt

# only-lvmt-w34  40m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 40m -a lvmt --shards 64

# only-lvmt-w35  40m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 40m -a lvmt --shards 16

# only-lvmt-w36  63m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 63m -a lvmt

# only-lvmt-w37  63m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 63m -a lvmt --shards 64

# only-lvmt-w38  63m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 63m -a lvmt --shards 16

# only-lvmt-w39  100m, plain
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 100m -a lvmt

# only-lvmt-w40  100m, s64
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 100m -a lvmt --shards 64

# only-lvmt-w41  100m, s16
rm -rf __benchmarks && cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 100m -a lvmt --shards 16
```

### Time Benchmark Commands (T00–T45)

Each time benchmark must be preceded by: `sudo sysctl -w vm.drop_caches=3`

```bash
# only-lvmt-t00  fresh, plain  (no warmup)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --no-warmup -k 10g --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_fresh.log

# only-lvmt-t01  fresh, s64  (no warmup)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --no-warmup -k 10g --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_fresh.log

# only-lvmt-t02  fresh, s16  (no warmup)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --no-warmup -k 10g --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_fresh.log

# only-lvmt-t03  fresh, s1  (no warmup)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --no-warmup -k 10g --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_fresh.log

# only-lvmt-t04  real, plain  (requires w00)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_real.log

# only-lvmt-t05  real, s64  (requires w01)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_real.log

# only-lvmt-t06  real, s16  (requires w02)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_real.log

# only-lvmt-t07  1m, plain  (requires w03)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_1m.log

# only-lvmt-t08  1m, s64  (requires w04)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_1m.log

# only-lvmt-t09  1m, s16  (requires w05)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_1m.log

# only-lvmt-t10  1m, s1  (requires w06)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_1m.log

# only-lvmt-t11  1600k, plain  (requires w07)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1600k --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_1600k.log

# only-lvmt-t12  1600k, s64  (requires w08)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1600k --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_1600k.log

# only-lvmt-t13  1600k, s16  (requires w09)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1600k --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_1600k.log

# only-lvmt-t14  1600k, s1  (requires w10)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1600k --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_1600k.log

# only-lvmt-t15  2500k, plain  (requires w11)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 2500k --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_2500k.log

# only-lvmt-t16  2500k, s64  (requires w12)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 2500k --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_2500k.log

# only-lvmt-t17  2500k, s16  (requires w13)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 2500k --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_2500k.log

# only-lvmt-t18  2500k, s1  (requires w14)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 2500k --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_2500k.log

# only-lvmt-t19  4m, plain  (requires w15)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 4m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_4m.log

# only-lvmt-t20  4m, s64  (requires w16)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 4m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_4m.log

# only-lvmt-t21  4m, s16  (requires w17)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 4m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_4m.log

# only-lvmt-t22  4m, s1  (requires w18)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 4m --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_4m.log

# only-lvmt-t23  6300k, plain  (requires w19)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 6300k --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_6300k.log

# only-lvmt-t24  6300k, s64  (requires w20)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 6300k --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_6300k.log

# only-lvmt-t25  6300k, s16  (requires w21)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 6300k --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_6300k.log

# only-lvmt-t26  6300k, s1  (requires w22)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 6300k --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_6300k.log

# only-lvmt-t27  10m, plain  (requires w23)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_10m.log

# only-lvmt-t28  10m, s64  (requires w24)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_10m.log

# only-lvmt-t29  10m, s16  (requires w25)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_10m.log

# only-lvmt-t30  10m, s1  (requires w26)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 2048 --shards 1 \
  > ./paper_experiment/osdi23/time_lvmt1_10m.log

# only-lvmt-t31  16m, plain  (requires w27)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 16m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_16m.log

# only-lvmt-t32  16m, s64  (requires w28)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 16m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_16m.log

# only-lvmt-t33  16m, s16  (requires w29)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 16m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_16m.log

# only-lvmt-t34  25m, plain  (requires w30)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 25m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_25m.log

# only-lvmt-t35  25m, s64  (requires w31)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 25m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_25m.log

# only-lvmt-t36  25m, s16  (requires w32)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 25m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_25m.log

# only-lvmt-t37  40m, plain  (requires w33)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 40m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_40m.log

# only-lvmt-t38  40m, s64  (requires w34)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 40m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_40m.log

# only-lvmt-t39  40m, s16  (requires w35)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 40m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_40m.log

# only-lvmt-t40  63m, plain  (requires w36)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 63m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_63m.log

# only-lvmt-t41  63m, s64  (requires w37)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 63m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_63m.log

# only-lvmt-t42  63m, s16  (requires w38)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 63m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_63m.log

# only-lvmt-t43  100m, plain  (requires w39)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 2048 \
  > ./paper_experiment/osdi23/time_lvmt_100m.log

# only-lvmt-t44  100m, s64  (requires w40)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 2048 --shards 64 \
  > ./paper_experiment/osdi23/time_lvmt64_100m.log

# only-lvmt-t45  100m, s16  (requires w41)
sudo sysctl -w vm.drop_caches=3 && rm -rf __benchmarks
./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 2048 --shards 16 \
  > ./paper_experiment/osdi23/time_lvmt16_100m.log
```

### Stat Benchmark Commands (S00–S14)

```bash
# only-lvmt-s00  fresh, plain  (no warmup)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --no-warmup -k 10g --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_fresh.log

# only-lvmt-s01  fresh, s64  (no warmup)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --no-warmup -k 10g --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_fresh.log

# only-lvmt-s02  fresh, s16  (no warmup)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --no-warmup -k 10g --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_fresh.log

# only-lvmt-s03  real, plain  (requires w00)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_real.log

# only-lvmt-s04  real, s64  (requires w01)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_real.log

# only-lvmt-s05  real, s16  (requires w02)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --warmup-from ./warmup/v4 --real-trace --report-epoch 25 --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_real.log

# only-lvmt-s06  1m, plain  (requires w03)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_1m.log

# only-lvmt-s07  1m, s64  (requires w04)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_1m.log

# only-lvmt-s08  1m, s16  (requires w05)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_1m.log

# only-lvmt-s09  10m, plain  (requires w23)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_10m.log

# only-lvmt-s10  10m, s64  (requires w24)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_10m.log

# only-lvmt-s11  10m, s16  (requires w25)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 10m --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_10m.log

# only-lvmt-s12  100m, plain  (requires w39)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 8192 \
  > ./paper_experiment/osdi23/stat_lvmt_100m.log

# only-lvmt-s13  100m, s64  (requires w40)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 8192 --shards 64 \
  > ./paper_experiment/osdi23/stat_lvmt64_100m.log

# only-lvmt-s14  100m, s16  (requires w41)
rm -rf __benchmarks
cargo run --release -- --max-time 5400 -a lvmt --max-epoch 200 --warmup-from ./warmup/v4 -k 100m --cache-size 8192 --shards 16 \
  > ./paper_experiment/osdi23/stat_lvmt16_100m.log
```

---

## Estimated Total Time

### Per-Phase Estimates

| Phase  | Runs | Best Case | Worst Case | Realistic  |
|--------|------|-----------|------------|------------|
| Warmup | 42   | ~8 h      | ~40 h      | ~15–25 h   |
| Time   | 46   | ~15 h     | ~69 h      | ~30–50 h   |
| Stat   | 15   | ~5 h      | ~22 h      | ~10–18 h   |
| **Total** | **103** | **~28 h** | **~131 h** | **~55–93 h** |

> **~2.5–4 days** of continuous execution for LVMT-only.  
> Compare to full suite (193 runs, all algorithms): **~4–7 days**.

### Time Budget by Key Size

| Key Size  | Warmup/run | Bench/run (time or stat)     |
|-----------|------------|------------------------------|
| 1m        | 1–3 min    | 5–15 min (200 epochs fast)   |
| 1600k     | 2–5 min    | 8–25 min                     |
| 2500k     | 3–6 min    | 12–35 min                    |
| 4m        | 5–12 min   | 20–50 min                    |
| 6300k     | 8–18 min   | 25–65 min                    |
| 10m       | 12–30 min  | 35–90 min                    |
| 16m       | 20–45 min  | 50–90 min (may hit cap)      |
| 25m       | 30–70 min  | 60–90 min (often hits cap)   |
| 40m       | 50–100 min | 70–90 min (usually hits cap) |
| 63m       | 70–140 min | 80–90 min (hits cap)         |
| 100m      | 90–180 min | ~90 min (hits cap)           |
| real      | 5–20 min   | ~90 min (hits cap)           |
| fresh/10g | N/A        | ~90 min (hits cap)           |

> All benchmarks hard-cap at **5400 s (90 min)**. Larger datasets are more likely to
> reach this cap before completing 200 epochs.

---

## Running All LVMT Only

### Option A: LVMT-Only Python Script

Create `run_lvmt_only.py` alongside `run.py`:

```python
#!/usr/bin/env python3
"""Run only LVMT experiments (103 total)."""
import subprocess, sys
from functools import partial
import numpy as np

CARGO_RUN = "cargo run --release --".split(" ")
DRY_RUN = False
WARMUP = "./warmup/v4"
RESULT = "./paper_experiment/osdi23"
CGRUN_PREFIX = "./cgrun.sh"


def run(commands, output=None):
    if type(commands) is str:
        commands = commands.split(" ")
    message = " ".join(commands) + (f" > {output}" if output else "")
    if DRY_RUN:
        print(message); return
    print(f"\n>>>>>>>>>>> {message}")
    sys.stdout.flush()
    out = open(output, "w") if output else None
    subprocess.run(commands, stdout=out)
    print(f"<<<<<<<<<<< done")
    sys.stdout.flush()


def warmup(key, shards=None):
    if key == "fresh":
        return
    prefix = CARGO_RUN + ["--no-stat", "--warmup-to", WARMUP]
    run("rm -rf __benchmarks")
    prefix = prefix + (["--real-trace"] if key == "real" else f"-k {key}".split(" "))
    cmd = prefix + "-a lvmt".split(" ")
    if shards is not None:
        cmd = cmd + f"--shards {shards}".split(" ")
    run(cmd)


def bench(task, key, shards=None):
    prefix = CARGO_RUN + f"--max-time 5400 -a lvmt".split(" ")
    if task == "time":
        prefix = prefix + ["--no-stat"]
        if CGRUN_PREFIX:
            prefix = CGRUN_PREFIX.split(" ") + prefix
            run("sudo sysctl -w vm.drop_caches=3")
    if key != "real":
        prefix = prefix + "--max-epoch 200".split(" ")
    if key == "fresh":
        prefix = prefix + ["--no-warmup"] + "-k 10g".split(" ")
    elif key == "real":
        prefix = prefix + f"--warmup-from {WARMUP} --real-trace --report-epoch 25".split(" ")
    else:
        prefix = prefix + f"--warmup-from {WARMUP} -k {key}".split(" ")
    cache = "8192" if task == "stat" else "2048"
    prefix = prefix + f"--cache-size {cache}".split(" ")
    run("rm -rf __benchmarks")
    tag = f"lvmt{shards}" if shards else "lvmt"
    output = f"{RESULT}/{task}_{tag}_{key}.log"
    cmd = prefix + (f"--shards {shards}".split(" ") if shards else [])
    run(cmd, output)


bench_time = partial(bench, "time")
bench_stat = partial(bench, "stat")

# ── Setup ──
run("rm -rf __reports __benchmarks")
run(f"mkdir -p {WARMUP}")
run(f"mkdir -p {RESULT}")

# ── Phase 1: Warmup (42 runs) ──
print("\n=== LVMT WARMUP (42 runs) ===")
for key in ["real","1m","1600k","2500k","4m","6300k","10m","16m","25m","40m","63m","100m"]:
    warmup(key)
    for shards in [64, 16, 1]:
        if shards == 1 and key in ["real","16m","25m","40m","63m","100m"]:
            continue
        warmup(key, shards)

# ── Phase 2: Time Benchmarks (46 runs) ──
print("\n=== LVMT TIME BENCHMARKS (46 runs) ===")
for key in ["fresh","real","1m","1600k","2500k","4m","6300k","10m","16m","25m","40m","63m","100m"]:
    bench_time(key)
    for shards in [64, 16, 1]:
        if shards == 1 and key in ["real","16m","25m","40m","63m","100m"]:
            continue
        bench_time(key, shards)

# ── Phase 3: Stat Benchmarks (15 runs) ──
print("\n=== LVMT STAT BENCHMARKS (15 runs) ===")
for key in ["fresh","real","1m","10m","100m"]:
    bench_stat(key)
    for shards in [64, 16]:
        bench_stat(key, shards)

print("\n=== ALL 103 LVMT EXPERIMENTS COMPLETE ===")
```

Run with: `python3 run_lvmt_only.py`  
Dry-run (show commands only): set `DRY_RUN = True` inside the script.

### Option B: Run a Subset

To run just one key size across all variants (e.g., 1m):

```bash
# Warmup (4 runs: plain, s64, s16, s1)
bash -c 'for s in "" 64 16 1; do
  rm -rf __benchmarks
  if [ -z "$s" ]; then
    cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt
  else
    cargo run --release -- --no-stat --warmup-to ./warmup/v4 -k 1m -a lvmt --shards $s
  fi
done'

# Time bench (4 runs)
bash -c 'for s in "" 64 16 1; do
  sudo sysctl -w vm.drop_caches=3
  rm -rf __benchmarks
  tag="lvmt${s}"
  if [ -z "$s" ]; then
    ./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 > ./paper_experiment/osdi23/time_lvmt_1m.log
  else
    ./cgrun.sh cargo run --release -- --max-time 5400 -a lvmt --no-stat --max-epoch 200 --warmup-from ./warmup/v4 -k 1m --cache-size 2048 --shards $s > ./paper_experiment/osdi23/time_${tag}_1m.log
  fi
done'
```

---

## Internal Details (Deep Reference)

### How Warmup Exits Cleanly

In `benchmarks/src/run.rs` line 72, after saving the warmup directory, the function calls `return;` — exiting `run_tasks()` before the benchmark loop begins. This means warmup-only runs (with `--warmup-to`) are **finite** and exit automatically.

### Bench Stop Condition

```rust
if elapsed_time >= max_time  OR  epoch >= max_epoch → BREAK
```

With `--max-time 5400 --max-epoch 200`: whichever limit is reached first.  
Real & fresh do NOT set `--max-epoch`, so they run until the 90-min cap.

### Epoch Mechanics

- Each epoch = 50,000 read-then-write pairs (100k total ops) for keyed workloads
- For real trace: 1 block group per epoch (LVMT gets 1 block/epoch; MPT/RAIN get 50)
- `--report-epoch 25` (real trace) → metrics every 25 epochs
- `--report-epoch 2` (default, keyed workloads) → metrics every 2 epochs

### Shard Implementation

`--shards N` converts to `(log₂(N), 0)` passed to `AMTNodeIndex::new(depth, index)`.  
This restricts the LVMT multi-layer version tree to a specific subtree, simulating a world where only that shard's data is maintained.

### Output Format

Time bench output (per report):
```
Time  123.456s, Epoch:    42, avg levels: 3.127, access writes [1234, 567, 89, 12], data writes 506 245
```

Stat bench output (per report):
```
Time  123.456s, Epoch:    42, Read amp  2.345, Write amp  1.234 > avg levels: 3.127, ...
```

### Warmup Directory Structure

```
./warmup/v4/
├── LVMT_real/          ← w00
├── LVMT64_real/        ← w01
├── LVMT16_real/        ← w02
├── LVMT_1e6/           ← w03
├── LVMT64_1e6/         ← w04
├── LVMT16_1e6/         ← w05
├── LVMT1_1e6/          ← w06
├── ...
├── LVMT_1e8/           ← w39
├── LVMT64_1e8/         ← w40
└── LVMT16_1e8/         ← w41
```

Both time and stat benchmarks use the **same** warmup snapshots.

---

## Source Traceability

| Aspect | Source File | Key Lines |
|--------|------------|-----------|
| Experiment definitions | `run.py` | warmup_all(), bench_all_time(), bench_all_stat() |
| CLI options & defaults | `asb-options/src/lib.rs` | struct Options |
| Warmup/bench loop | `benchmarks/src/run.rs` | run_tasks(), warmup() |
| LVMT shard init | `asb-authdb/src/lvmt.rs` | new(), shard_info |
| Shard tree logic | `asb-authdb/lvmt-db/src/lvmt_db.rs` | AMTNodeIndex |
| Workload generator | `asb-tasks/src/read_then_write.rs` | warmup(), tasks() |
| Real trace loader | `asb-tasks/src/real_trace.rs` | warmup(), group_size |
