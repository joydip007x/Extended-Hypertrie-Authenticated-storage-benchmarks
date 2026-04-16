# Environment Setup — Authenticated Storage Benchmarks

## System Requirements (Verified)

| Component | Required | Installed |
|-----------|----------|-----------|
| OS | Ubuntu 22.04+ | Ubuntu 24.04 (compatible) |
| Rust | 1.67.0 (exact) | 1.67.0 via rustup |
| Cargo | matching | 1.67.0 |
| GCC | any (needs compat flags for 13+) | GCC 13 |
| cmake | yes | 3.28.3 |
| libclang-dev | yes | 18.0 |
| libssl-dev | yes | 3.0.13 |
| pkg-config | yes | 1.8.1 |
| build-essential | yes | 12.10 |
| Python3 | yes | 3.12.3 |
| numpy | yes | 1.26.4 |
| cgroup tools | cgcreate, cgclassify | installed |

## Critical Environment Variables

These MUST be set before ANY cargo/build command:

```bash
export PATH="$HOME/.cargo/bin:$PATH"      # Use rustup's Rust 1.67.0, not system Rust
export CXXFLAGS="-Wno-error -include cstdint"  # GCC 13 compatibility for RocksDB/TitanDB
```

### Why These Are Needed

- **PATH**: System has Rust 1.75.0 at `/usr/bin/rustc`. The project REQUIRES 1.67.0
  (defined in `rust-toolchain` file). Rustup installs 1.67.0 at `~/.cargo/bin/rustc`.
  Without this PATH override, `num-bigint v0.4.0` fails to compile on Rust 1.75.0.
- **CXXFLAGS**: GCC 13 (Ubuntu 24.04) breaks RocksDB/TitanDB C++ compilation:
  - `-Wno-error`: TitanDB uses `-Werror` and GCC 13 flags array-bounds warnings
  - `-include cstdint`: GCC 13 removed implicit `<cstdint>` include; `uint64_t` undefined without it

## Memory Limit (8GB via cgroup v2)

The original paper experiments used 8GB memory limit. This system has 31GB RAM,
so we use cgroup v2 to enforce the limit.

### Verification

```
/sys/fs/cgroup/lvmt/memory.max = 8589934592  (= 8 × 1024 × 1024 × 1024 = 8GB exact)
```

### How It Works

1. `setup_sudo.sh` creates `/sys/fs/cgroup/lvmt` with `memory.max = 8GB`
2. `cgrun.sh` moves the benchmark process into this cgroup before execution
3. `run.py` prepends `./cgrun.sh` to time-benchmark commands via `CGRUN_PREFIX`
4. Only **time benchmarks** run under the 8GB limit (stat benchmarks do not)

### Passwordless Sudo (configured in `/etc/sudoers.d/asb-benchmarks`)

- `sudo cgclassify` — move processes to cgroup
- `sudo sysctl -w vm.drop_caches=3` — drop page cache between time-bench runs
- `sudo tee /sys/fs/cgroup/lvmt/cgroup.procs` — assign process to cgroup

## File Placement

| Path | Contents | Source |
|------|----------|--------|
| `pp/` | `amt-params-ho1sTw-16.bin`, `power-tau-ho1sTw-16.bin` | [Google Drive download](https://drive.google.com/file/d/1pHiHpZ4eNee17C63tSDEvmcEVtv23-jK/view) |
| `trace/` | `real_trace.data`, `real_trace.init` | [OneDrive download](https://1drv.ms/f/s!Au7Bejk2NtCskXmvzwgS2WgDvuGV?e=ESZ5na) |

**Note**: The `pp/` files only cover `lvmt` and `amt16`. Other AMT heights (e.g., `amt20`, `amt24`)
will auto-generate their crypto parameters on first use (takes minutes to hours).

## Build Command

```bash
export PATH="$HOME/.cargo/bin:$PATH"
export CXXFLAGS="-Wno-error -include cstdint"
cargo build --release
```

Binary output: `target/release/asb-main` (~17.5MB)
