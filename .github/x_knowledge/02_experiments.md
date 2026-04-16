# Experiment Types & Default Configurations

## Overview

The `run.py` script runs **193 total experiment runs** across 3 phases.
These exactly reproduce the OSDI'23 paper evaluation.

---

## The 4 Major Experiment Categories

### Category 1: Warmup (Phase 1) — 78 runs

**Purpose**: Pre-populate databases with initial state before benchmarking.
Not a measurement — this creates saved database snapshots for later reuse.

| What | Value |
|------|-------|
| Algorithms | raw, lvmt, rain, mpt, lvmt+shards(64,16,1) |
| Key sizes | real, 1m, 1.6m, 2.5m, 4m, 6.3m, 10m, 16m, 25m, 40m, 63m, 100m |
| Flags | `--no-stat --warmup-to ./warmup/v4` |
| Output | Saved to `./warmup/v4/<Algorithm>_<keysize>/` |
| Memory limit | None (warmup runs without cgroup) |
| "fresh" key | Skipped (no warmup needed — starts from empty DB) |

**Shard exception**: `lvmt` shard=1 is skipped for large sizes (real, 16m+)
because single-shard LVMT is too slow at scale.

---

### Category 2: Time Benchmarks (Phase 2) — 85 runs

**Purpose**: Measure execution time (throughput, ops/sec) of each algorithm.
This is the PRIMARY measurement — the paper's main results.

| What | Value |
|------|-------|
| Algorithms | raw, lvmt, rain, mpt, lvmt+shards(64,16,1) |
| Key sizes | fresh, real, 1m, 1.6m, 2.5m, 4m, 6.3m, 10m, 16m, 25m, 40m, 63m, 100m |
| Max time per run | 5400 seconds (90 minutes) |
| Max epochs | 200 (non-real traces only) |
| Flags | `--no-stat` (disables backend stats for accurate timing) |
| Memory limit | **8GB via cgroup** (only this phase uses the memory limit) |
| Cache drop | `sudo sysctl -w vm.drop_caches=3` before each run |
| Output | `./paper_experiment/osdi23/time_<alg>_<key>.log` |

**Cache sizes** (RocksDB block cache):
- `raw`, `mpt`: 4096 MB
- `lvmt`, `rain`, `lvmt+shards`: 2048 MB

**Special keys**:
- `fresh`: No warmup, 10 billion keys (`-k 10g --no-warmup`) — tests from-scratch insertion
- `real`: Uses real Ethereum traces (`--real-trace`), report_epoch=1 for rain/mpt, 25 for others

---

### Category 3: Stat Benchmarks (Phase 3) — 30 runs

**Purpose**: Measure read/write amplification to the backend database.
Runs WITH backend statistics enabled (slightly slower but captures I/O metrics).

| What | Value |
|------|-------|
| Algorithms | raw, lvmt, rain, mpt, lvmt+shards(64,16) |
| Key sizes | fresh, real, 1m, 10m, 100m (subset — only 5 sizes) |
| Max time per run | 5400 seconds (90 minutes) |
| Max epochs | 200 (non-real traces only) |
| Flags | (no `--no-stat` — stats are enabled) |
| Memory limit | **None** (stat bench does NOT use cgroup) |
| Cache size | 8192 MB for all algorithms |
| Output | `./paper_experiment/osdi23/stat_<alg>_<key>.log` |

**Note**: shard=1 is NOT tested in stat benchmarks (only 64, 16).

---

### Category 4: LMPTs Special Case (NOT in default run.py)

**Purpose**: Benchmark Lightweight MPTs (Conflux's storage).
This is NOT included in `run.py` because it requires manual Cargo.toml changes.

| What | Value |
|------|-------|
| Algorithm | `lmpts` |
| Special build | Must modify `asb-backend/Cargo.toml` (comment out cfx-kvdb-rocksdb, uncomment lmpts-backend) |
| Build command | `cargo build --release --features asb-authdb/lmpts` |
| Why special | Dependency conflict — LMPTs and regular RocksDB can't coexist |

---

## Algorithm Reference

| CLI Name | Full Name | Description |
|----------|-----------|-------------|
| `raw` | Raw/No Auth | Writes directly to backend, no authenticated storage. Baseline. |
| `mpt` | Merkle Patricia Trie | OpenEthereum's original MPT implementation |
| `rain` | RainBlock MPT | Modified RainBlock's MPT with local bottom-layer storage |
| `lvmt` | Multi-Layer Versioned Multipoint Trie | **The paper's new contribution** (OSDI'23) |
| `lvmt --shards N` | LVMT with Proof Sharding | LVMT maintaining proof info, N = power of 2 (1–65536) |
| `amt<n>` | Authenticated Multipoint Tree | Single AMT with height n (max 28). Building block of LVMT. |
| `lmpts` | Layered Merkle Patricia Tries | Conflux's storage (special build required) |

## Backend Reference

| CLI Name | Description | Default |
|----------|-------------|---------|
| `rocksdb` | RocksDB persistent KV store | **YES** (default) |
| `memory` | In-memory hashmap (OpenEthereum) | No |
| `mdbx` | MDBX (used by Erigon) | No (not fully tested) |

---

## Default Program Parameters (from source code)

These are the compiled-in defaults in `asb-options/src/lib.rs`:

| Parameter | CLI Flag | Default Value | run.py Override |
|-----------|----------|---------------|-----------------|
| Backend | `-b` / `--backend` | `rocksdb` | (unchanged) |
| Total keys | `-k` / `--total-keys` | 100,000 | varies per experiment |
| Seed | `--seed` | 64 | (unchanged) |
| RocksDB cache (MB) | `--cache-size` | 1500 | 2048/4096/8192 |
| Max time (sec) | `--max-time` | None (unlimited) | 5400 |
| Max epochs | `--max-epoch` | None (unlimited) | 200 |
| Report epoch | `--report-epoch` | 2 | 1 or 25 for real traces |
| Profile epoch | `--profile-epoch` | 100 | (unchanged) |
| Epoch size (ops) | `--epoch-size` | 50,000 | (unchanged) |
| DB directory | `--db` | `./__benchmarks` | (unchanged) |
| Trace directory | `--trace` | `./trace` | (unchanged) |
| Real trace | `--real-trace` | false | true for "real" key |
| Backend stats | `--no-stat` | false (stats ON) | ON for time bench |
| Memory stats | `--stat-mem` | false | (unchanged) |
| No warmup | `--no-warmup` | false | true for "fresh" |
| Shards | `--shards` | None | 1, 16, or 64 |

---

## Quick-Run Examples

### Run a single quick test (1 minute):
```bash
export PATH="$HOME/.cargo/bin:$PATH"
./target/release/asb-main --no-stat -k 1m -a mpt --max-time 60 --max-epoch 5
```

### Run the full OSDI'23 experiment suite:
```bash
export PATH="$HOME/.cargo/bin:$PATH"
export CXXFLAGS="-Wno-error -include cstdint"
python3 run.py
```

### Run a single algorithm with real Ethereum traces:
```bash
./target/release/asb-main --no-stat --real-trace -a lvmt --max-time 300
```

### Run LVMT with proof sharding (64 shards):
```bash
./target/release/asb-main --no-stat -k 10m -a lvmt --shards 64 --max-time 300
```
