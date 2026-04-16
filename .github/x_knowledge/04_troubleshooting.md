# Troubleshooting & Known Issues

## Build Failures

### Error: `uint64_t does not name a type` (GCC 13)
**Cause**: GCC 13 removed implicit `<cstdint>` include. RocksDB/TitanDB C++ code relies on it.
**Fix**: `export CXXFLAGS="-Wno-error -include cstdint"` before `cargo build`

### Error: `array subscript 153 is above array bounds` (GCC 13)
**Cause**: GCC 13 array-bounds warning + `-Werror` in TitanDB.
**Fix**: Same `CXXFLAGS` as above includes `-Wno-error`.

### Error: `mismatched types u64 / &u64` in num-bigint
**Cause**: Using system Rust 1.75.0 instead of required 1.67.0. The `div_ceil` API changed.
**Fix**: Use rustup Rust 1.67.0: `export PATH="$HOME/.cargo/bin:$PATH"`

### Error: `Blocking waiting for file lock on package cache`
**Cause**: Another cargo process is running.
**Fix**: `ps aux | grep cargo` and kill duplicates, or wait.

## Runtime Issues

### cgroup v2 vs v1
This system uses cgroup v2 (Ubuntu 24.04). The README instructions are for cgroup v1.
- v1: `sudo cgcreate -g memory:/lvmt` + `memory.limit_in_bytes`
- v2: `sudo mkdir /sys/fs/cgroup/lvmt` + `memory.max`
Our scripts handle v2 correctly.

### Passwordless sudo failing
Check `/etc/sudoers.d/asb-benchmarks` exists and has correct user:
```bash
sudo cat /etc/sudoers.d/asb-benchmarks
```
Re-run `sudo bash setup_sudo.sh` if missing.

### tcsh vs bash
The default shell on this system is `tcsh`. Many bash-specific commands fail.
Always wrap in `bash -c '...'` or switch shells with `bash` first.
The `startup.sh` and `cgrun.sh` scripts use `#!/bin/bash` explicitly.

### `.bashrc` owned by root
This happened on initial setup. Fixed with: `sudo chown q36dd:sudo ~/.bashrc`

## Performance Notes

- Full `run.py` takes 1-2 days (193 runs × up to 90 min each)
- RocksDB C++ compilation takes ~10-15 minutes (one-time)
- Rust compilation takes ~2-3 minutes after C++ libs are built
- `pp/` crypto params for AMT heights other than 16 will auto-generate (slow first run)
- The `__benchmarks/` directory is deleted between runs (no accumulation)
