#!/bin/bash
# ============================================================================
# Authenticated Storage Benchmarks — Setup & Run Script (Ubuntu/Linux)
# ============================================================================
# Replaces startup.ps1 (Windows). Run this to set up environment and launch
# the full experiment suite from the original OSDI'23 paper.
#
# Usage:
#   ./startup.sh           # Full setup + run all experiments
#   ./startup.sh --setup   # Setup only (cgroup, dirs) — no experiments
#   ./startup.sh --run     # Run experiments only (assumes setup done)
# ============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Ensure rustup's Rust 1.67.0 is on PATH
export PATH="$HOME/.cargo/bin:$PATH"

# GCC 13 compatibility flags for RocksDB/TitanDB C++ compilation
export CXXFLAGS="-Wno-error -include cstdint"

# ---- Helper Functions ----
info()  { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

check_prereqs() {
    info "Checking prerequisites..."

    # Rust
    if ! command -v rustc &>/dev/null; then
        error "rustc not found. Install via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    fi
    RUST_VER=$(rustc --version)
    info "Rust: $RUST_VER"

    # Python + numpy
    if ! python3 -c "import numpy" &>/dev/null; then
        error "numpy not found. Install via: pip3 install numpy"
        exit 1
    fi
    info "Python3 + numpy: OK"

    # pp/ files
    if [ ! -f pp/power-tau-ho1sTw-16.bin ]; then
        warn "pp/ crypto params not found — LVMT/AMT will need to generate them (slow)."
    else
        info "pp/ crypto params: OK"
    fi

    # trace/ files
    if [ ! -f trace/real_trace.data ]; then
        warn "trace/real_trace.data not found — real Ethereum trace experiments will fail."
    else
        info "trace/ Ethereum traces: OK"
    fi

    # Disk space
    FREE_GB=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$FREE_GB" -lt 300 ]; then
        warn "Only ${FREE_GB}GB free disk. Full experiments need ~300GB."
    else
        info "Disk space: ${FREE_GB}GB free (300GB needed)"
    fi
}

setup_cgroup() {
    info "Setting up cgroup v2 memory limit (8GB)..."

    # Enable memory controller in subtree
    if ! grep -q "memory" /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null; then
        echo "+memory" | sudo tee /sys/fs/cgroup/cgroup.subtree_control >/dev/null
        info "Enabled memory controller in cgroup subtree"
    fi

    # Create lvmt cgroup
    if [ ! -d /sys/fs/cgroup/lvmt ]; then
        sudo mkdir -p /sys/fs/cgroup/lvmt
        info "Created /sys/fs/cgroup/lvmt"
    fi

    # Set 8GB memory limit
    echo $((8*1024*1024*1024)) | sudo tee /sys/fs/cgroup/lvmt/memory.max >/dev/null
    info "Set memory.max = 8GB for cgroup /lvmt"

    # Verify
    MEM_MAX=$(cat /sys/fs/cgroup/lvmt/memory.max)
    info "Verified memory.max = $MEM_MAX bytes"
}

build_project() {
    info "Building project (release mode)..."
    if [ -f target/release/asb-main ]; then
        info "Binary already exists. Skipping build. (Delete target/ to force rebuild)"
        return
    fi
    cargo build --release
    info "Build complete: target/release/asb-main"
}

create_dirs() {
    mkdir -p warmup/v4
    mkdir -p paper_experiment/osdi23
    info "Created output directories"
}

run_experiments() {
    info "==============================================="
    info "Starting full experiment suite (run.py)"
    info "This reproduces the OSDI'23 paper experiments."
    info "Memory limit: 8GB via cgroup"
    info "Max time per run: 90 minutes"
    info "Total: ~200 runs (may take 1-2 days)"
    info "Results → ./paper_experiment/osdi23/"
    info "==============================================="
    python3 run.py
}

cleanup_stale() {
    # Kill any leftover benchmark processes
    pkill -f asb-main 2>/dev/null || true
    rm -rf __benchmarks __reports 2>/dev/null || true
}

# ---- Main ----
MODE="${1:-all}"

case "$MODE" in
    --setup)
        check_prereqs
        setup_cgroup
        build_project
        create_dirs
        info "Setup complete. Run './startup.sh --run' to start experiments."
        ;;
    --run)
        cleanup_stale
        run_experiments
        ;;
    *)
        check_prereqs
        setup_cgroup
        build_project
        create_dirs
        cleanup_stale
        run_experiments
        ;;
esac
