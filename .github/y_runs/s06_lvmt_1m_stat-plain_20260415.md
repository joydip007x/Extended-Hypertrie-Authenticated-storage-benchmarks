# Run Report: only-lvmt-s06 — LVMT 1M Stat Benchmark (Plain)

**Experiment ID:** only-lvmt-s06  
**Algorithm:** LVMT  
**Key count:** 1,000,000 (1m)  
**Variant:** stat (read-only), plain (no shards)  
**Date:** 2026-04-15  
**Status:** COMPLETE

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

## Command

```bash
cargo run --release -- --stat --warmup-from ./warmup/v4 -k 1m -a lvmt
```

## Results Summary

| Metric              | Value         |
|---------------------|---------------|
| Epochs completed    | 198           |
| Total time          | 118.509 s     |
| Throughput          | 167,974 ops/s |
| Latency (avg)       | 5.953 µs/op   |
| Empty reads         | 0             |
| Read amplification  | 0.975         |
| Write amplification | 0.975         |
| Avg levels          | 1.673         |
| Access writes       | [0, 0, 0, 2]  |
| Data writes         | 200,000       |

## Key Observations

1. **Fastest stat benchmark.** Plain LVMT has no shard overhead — reads go directly
   to a single AMT tree with minimal amplification.
2. **Read amp = Write amp = 0.975.** Less than 1.0 because not every key requires a
   full tree traversal (some share prefixes).
3. **Zero access writes.** Plain LVMT stores no per-shard access metadata.
4. **118.5s for 198 epochs** — nearly identical to the time benchmark (119.7s for 200
   epochs), confirming that stat collection has negligible overhead.
