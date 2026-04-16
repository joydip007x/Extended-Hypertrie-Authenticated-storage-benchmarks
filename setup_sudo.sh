#!/bin/bash
# ============================================================================
# One-time sudo setup for Authenticated Storage Benchmarks
# Run with: sudo bash setup_sudo.sh
# ============================================================================
set -e

USERNAME=$(logname 2>/dev/null || echo "${SUDO_USER:-q36dd}")
echo "Setting up for user: $USERNAME"

# 1. Create cgroup v2 directory with 8GB memory limit
echo "--- Setting up cgroup v2 (8GB memory limit) ---"
if ! grep -q "memory" /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null; then
    echo "+memory" > /sys/fs/cgroup/cgroup.subtree_control
    echo "Enabled memory controller"
fi

mkdir -p /sys/fs/cgroup/lvmt
echo $((8*1024*1024*1024)) > /sys/fs/cgroup/lvmt/memory.max
echo "cgroup /lvmt created with memory.max = $(cat /sys/fs/cgroup/lvmt/memory.max)"

# 2. Set up passwordless sudo for cgclassify, sysctl, and tee (for cgroup.procs)
echo "--- Setting up passwordless sudo entries ---"
SUDOERS_FILE="/etc/sudoers.d/asb-benchmarks"
cat > "$SUDOERS_FILE" << EOF
# Authenticated Storage Benchmarks — passwordless sudo for cgroup & sysctl
$USERNAME ALL=NOPASSWD: /usr/bin/cgclassify
$USERNAME ALL=NOPASSWD: /usr/sbin/sysctl
$USERNAME ALL=NOPASSWD: /sbin/sysctl
$USERNAME ALL=NOPASSWD: /usr/bin/tee /sys/fs/cgroup/lvmt/cgroup.procs
$USERNAME ALL=NOPASSWD: /usr/bin/tee /sys/fs/cgroup/lvmt/memory.max
$USERNAME ALL=NOPASSWD: /usr/bin/tee /sys/fs/cgroup/cgroup.subtree_control
EOF
chmod 440 "$SUDOERS_FILE"
echo "Created $SUDOERS_FILE"

# 3. Verify
echo ""
echo "=== Setup Complete ==="
echo "Memory limit: $(cat /sys/fs/cgroup/lvmt/memory.max) bytes (8GB)"
echo "Sudoers file: $SUDOERS_FILE"
echo "User $USERNAME can now run benchmarks with 8GB memory constraint."
echo ""
echo "To run experiments:"
echo "  cd $(pwd)"
echo "  ./startup.sh"
