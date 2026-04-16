#!/bin/bash

# Ensure rustup's cargo/rustc is on PATH
export PATH="$HOME/.cargo/bin:$PATH"

# GCC 13 compatibility for RocksDB C++ build
export CXXFLAGS="-Wno-error -include cstdint"

# Classify the current shell into the 'lvmt' memory cgroup (cgroupv2)
echo $$ | sudo tee /sys/fs/cgroup/lvmt/cgroup.procs >/dev/null
COMMAND=$@

bash -c "$COMMAND"
