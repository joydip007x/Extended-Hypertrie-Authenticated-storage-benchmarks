# Project Structure & Architecture

## Workspace Layout

```
├── Cargo.toml              # Workspace root — defines all members
├── run.py                  # Master experiment runner (Python)
├── rust-toolchain          # Pins Rust to 1.67.0
├── startup.sh              # Linux setup + run script
├── cgrun.sh                # cgroup memory wrapper (8GB limit)
├── setup_sudo.sh           # One-time sudo setup (cgroup + sudoers)
├── pp/                     # Cryptographic parameters (download)
├── trace/                  # Ethereum trace data (download)
│
├── benchmarks/             # Binary crate: asb-main (the benchmark runner)
│   └── src/
│       ├── main.rs         # Entry point, parses options, dispatches
│       └── run.rs          # Task runner, connects auth-db + backend + task
│
├── asb-options/            # CLI options & parameter parsing
│   └── src/lib.rs          # StructOpt definitions, AuthAlgo/Backend enums
│
├── asb-backend/            # Storage backends
│   ├── src/
│   │   ├── lib.rs
│   │   ├── cfx_kvdb_rocksdb.rs   # RocksDB backend
│   │   ├── mdbx.rs               # MDBX backend
│   │   ├── in_mem_with_metrics.rs # In-memory backend
│   │   └── db_with_mertics.rs     # Metrics wrapper
│   └── cfx-kvdb-rocksdb/         # Conflux's RocksDB binding
│
├── asb-authdb/             # Authenticated storage implementations
│   ├── src/
│   │   ├── lib.rs          # Dispatches to selected algorithm
│   │   ├── mpt.rs          # OpenEthereum MPT adapter
│   │   ├── rain_mpt.rs     # RainBlock MPT adapter
│   │   ├── lvmt.rs         # LVMT adapter
│   │   ├── amt.rs          # Single AMT adapter
│   │   ├── lmpts.rs        # LMPTs adapter (special build)
│   │   └── raw.rs          # No-auth passthrough
│   ├── authdb-trait/       # Trait interface for all auth-DBs
│   ├── blake2-hasher/      # Blake2b hash function
│   ├── lvmt-db/            # LVMT core implementation
│   ├── patricia-trie-ethereum/  # OpenEthereum MPT
│   ├── rainblock-trie/     # RainBlock MPT
│   └── parity-journaldb/   # Journal DB utilities
│
├── asb-tasks/              # Workload generators
│   └── src/
│       ├── lib.rs
│       ├── read_then_write.rs    # Random workload
│       └── real_trace.rs         # Ethereum trace replay
│
├── asb-profile/            # Profiling & metrics
│   └── src/
│       ├── lib.rs
│       ├── profiler.rs     # pprof integration
│       └── counter.rs      # Metric counters
│
├── warmup/                 # Created at runtime — saved DB snapshots
├── paper_experiment/       # Created at runtime — experiment log outputs
└── __benchmarks/           # Created at runtime — active DB directory
```

## Data Flow

```
run.py
  └─> cargo run --release -- [args]    (or cgrun.sh cargo run ...)
        └─> asb-main (benchmarks/src/main.rs)
              ├─> asb-options: parse CLI args
              ├─> asb-backend: create RocksDB/Memory/MDBX backend
              ├─> asb-authdb: create MPT/LVMT/Rain/AMT/Raw on top of backend
              ├─> asb-tasks: generate random or real-trace workload
              ├─> WARMUP: insert initial keys (or load from --warmup-from)
              ├─> BENCHMARK: run epochs, measure time & stats
              └─> OUTPUT: print metrics to stdout (redirected to .log files by run.py)
```

## Compile Features

| Feature Flag | Effect |
|-------------|--------|
| `asb-authdb/light-hash` | Replace keccak256 with faster blake2b |
| `asb-authdb/thread-safe` | Thread-safe auth storage (only affects RainBlock MPT) |
| `asb-authdb/lmpts` | Enable LMPTs (requires Cargo.toml edits) |
