# run.py Detailed Breakdown — All 193 Experiments

This documents every experiment that `python3 run.py` executes, in order.

## Phase 1: Warmup (78 runs)

Creates saved database snapshots in `./warmup/v4/`.
Each run: cleans `__benchmarks/`, inserts initial data, saves to warmup dir.

### Base algorithms (4 per key size × 12 key sizes = 48 runs)

| # | Algorithm | Key Size | Command (simplified) |
|---|-----------|----------|---------------------|
| 1–4 | raw, lvmt, rain, mpt | real | `--no-stat --warmup-to ./warmup/v4 --real-trace -a <alg>` |
| 5–8 | raw, lvmt, rain, mpt | 1m | `--no-stat --warmup-to ./warmup/v4 -k 1m -a <alg>` |
| 9–12 | raw, lvmt, rain, mpt | 1600k | ... |
| 13–16 | raw, lvmt, rain, mpt | 2500k | ... |
| 17–20 | raw, lvmt, rain, mpt | 4m | ... |
| 21–24 | raw, lvmt, rain, mpt | 6300k | ... |
| 25–28 | raw, lvmt, rain, mpt | 10m | ... |
| 29–32 | raw, lvmt, rain, mpt | 16m | ... |
| 33–36 | raw, lvmt, rain, mpt | 25m | ... |
| 37–40 | raw, lvmt, rain, mpt | 40m | ... |
| 41–44 | raw, lvmt, rain, mpt | 63m | ... |
| 45–48 | raw, lvmt, rain, mpt | 100m | ... |

### LVMT with shards (30 runs)

| Key Size | Shard 64 | Shard 16 | Shard 1 |
|----------|----------|----------|---------|
| real | ✓ | ✓ | ✗ (skipped) |
| 1m | ✓ | ✓ | ✓ |
| 1600k | ✓ | ✓ | ✓ |
| 2500k | ✓ | ✓ | ✓ |
| 4m | ✓ | ✓ | ✓ |
| 6300k | ✓ | ✓ | ✓ |
| 10m | ✓ | ✓ | ✓ |
| 16m | ✓ | ✓ | ✗ (skipped) |
| 25m | ✓ | ✓ | ✗ (skipped) |
| 40m | ✓ | ✓ | ✗ (skipped) |
| 63m | ✓ | ✓ | ✗ (skipped) |
| 100m | ✓ | ✓ | ✗ (skipped) |

**Total warmup**: 48 + 30 = **78 runs**

---

## Phase 2: Time Benchmarks (85 runs)

Measures execution time. Runs under 8GB memory cgroup. Drops page cache before each run.
Output: `./paper_experiment/osdi23/time_<alg>_<key>.log`

### Common flags
- `--max-time 5400 --no-stat`
- `--warmup-from ./warmup/v4` (except "fresh")
- Preceded by `sudo sysctl -w vm.drop_caches=3`
- Wrapped in `./cgrun.sh` (8GB memory limit)

### Base algorithms (4 per key size × 13 key sizes = 52 runs)

| Key Size | Keys Flag | Cache (MB) | Max Epochs | Special |
|----------|-----------|------------|------------|---------|
| fresh | `-k 10g --no-warmup` | 4096 (raw,mpt) / 2048 (lvmt,rain) | 200 | From empty DB |
| real | `--real-trace` | Same | unlimited | report_epoch=1 (mpt,rain) or 25 |
| 1m | `-k 1m` | Same | 200 | — |
| 1600k | `-k 1600k` | Same | 200 | — |
| 2500k | `-k 2500k` | Same | 200 | — |
| 4m | `-k 4m` | Same | 200 | — |
| 6300k | `-k 6300k` | Same | 200 | — |
| 10m | `-k 10m` | Same | 200 | — |
| 16m | `-k 16m` | Same | 200 | — |
| 25m | `-k 25m` | Same | 200 | — |
| 40m | `-k 40m` | Same | 200 | — |
| 63m | `-k 63m` | Same | 200 | — |
| 100m | `-k 100m` | Same | 200 | — |

### LVMT sharded time benchmarks (33 runs)

Same shard skip rules as warmup, plus "fresh" key size (3 shards for fresh, since it's not in skip list).

**Total time bench**: 52 + 33 = **85 runs**

---

## Phase 3: Stat Benchmarks (30 runs)

Measures read/write amplification with backend statistics enabled.
Output: `./paper_experiment/osdi23/stat_<alg>_<key>.log`

### Common flags
- `--max-time 5400 --cache-size 8192`
- NO `--no-stat` (stats enabled)
- NO cgroup memory limit
- NO page cache drop

### Base algorithms (4 per key size × 5 key sizes = 20 runs)

| Key Size | Keys Flag |
|----------|-----------|
| fresh | `-k 10g --no-warmup` |
| real | `--real-trace` |
| 1m | `-k 1m` |
| 10m | `-k 10m` |
| 100m | `-k 100m` |

### LVMT sharded stat benchmarks (10 runs)
Shards 64 and 16 only (no shard=1), × 5 key sizes = 10 runs.

**Total stat bench**: 20 + 10 = **30 runs**

---

## Grand Total: 78 + 85 + 30 = **193 runs**

### Estimated Time
- Warmup: ~10-60 min per run depending on key size
- Time bench: up to 90 min each (5400s max)
- Stat bench: up to 90 min each
- **Realistic total: 1–3 days** depending on hardware
