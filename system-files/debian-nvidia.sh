#!/bin/sh
# NVIDIA driver on Debian 13 "trixie".
#
# Why this exists: Debian's own non-free archive ships nvidia-driver 550.163.01
# (trixie, trixie-backports and forky all agree) and Blackwell — the RTX 50
# series — needs 570 or newer. NVIDIA publishes a proper apt repo per Debian
# release, so on this box the driver comes from there instead.
#
#     sudo bash system-files/debian-nvidia.sh
#
# Idempotent: re-running upgrades the driver. Skip it entirely on a machine
# without an NVIDIA GPU (the script checks).
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run me with sudo:  sudo bash $0" >&2; exit 1; }

DEB_RELEASE=${DEB_RELEASE:-debian13}
REPO="https://developer.download.nvidia.com/compute/cuda/repos/$DEB_RELEASE/x86_64"

echo "══ 1/4 GPU check"
if ! lspci -nn | grep -qiE 'vga|3d|display.*\[10de:'; then
    echo "   no NVIDIA GPU found - nothing to do"; exit 0
fi
lspci -nn | grep -iE 'vga|3d|display' | sed 's/^/   /'

echo "══ 2/4 build deps (DKMS needs the headers for the RUNNING kernel)"
apt-get update -qq
apt-get install -y --no-install-recommends \
    linux-headers-"$(uname -r)" dkms build-essential ca-certificates curl

echo "══ 3/4 NVIDIA apt repo ($DEB_RELEASE)"
if dpkg -s cuda-keyring >/dev/null 2>&1; then
    echo "   cuda-keyring already installed"
else
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/cuda-keyring.deb" "$REPO/cuda-keyring_1.1-1_all.deb"
    dpkg -i "$tmp/cuda-keyring.deb"
    apt-get update -qq
fi

echo "══ 4/4 driver (open kernel modules - required on Turing and newer)"
# nvidia-open pulls nvidia-kernel-open-dkms + nvidia-driver + nvidia-driver-cuda.
# If Debian's own 550 packages are already present they must go first: the two
# packagings claim the same file paths and apt will refuse to unpack otherwise.
if dpkg -s nvidia-kernel-dkms >/dev/null 2>&1; then
    echo "   removing Debian's 550 driver first (conflicting package names)"
    apt-get purge -y 'nvidia-*' || true
fi
apt-get install -y nvidia-open

cat <<'EOF'

✔ Driver installed.

  * Secure Boot: if it is ON, the DKMS module must be enrolled, otherwise the
    kernel refuses to load it. Check with `mokutil --sb-state`. This box (the
    Ryzen desktop) has it OFF, so nothing to do.
  * Reboot, then: `nvidia-smi` should list the GPU.
  * /etc/X11/xorg.conf.d/10-nvidia.conf is machine-specific and NOT tracked by
    the repo - copy yours from a backup, or let X autodetect (nvidia-drm modeset).
  * The driver updates through normal `apt upgrade` from now on.
EOF
