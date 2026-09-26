#!/bin/sh
# Root-side installation for i3-dotfiles: everything that lives OUTSIDE $HOME.
#
# Run this AFTER ./install.sh (which stows the user files):
#     sudo bash system-files/install-system.sh
#
# Idempotent. Anything it would overwrite gets a copy next to it as
# <file>.bak-YYYY-MM-DD first. Nothing is deleted, nothing is uninstalled.
#
# It does NOT install packages — do that first:
#     sudo pacman -S --needed $(grep -v '^#' packages.txt | tr '\n' ' ')

set -eu
[ "$(id -u)" -eq 0 ] || { echo "run me with sudo:  sudo bash $0" >&2; exit 1; }
cd "$(dirname "$0")"

backup() {
    if [ -e "$1" ] && [ ! -L "$1" ]; then
        cp -a "$1" "$1.bak-$(date +%F)"
        echo "   backup: $1.bak-$(date +%F)"
    fi
}

echo "══ 1/3 mouse acceleration (Xorg)"
backup /etc/X11/xorg.conf.d/99-mouse-noaccel.conf
install -Dm644 99-mouse-noaccel.conf /etc/X11/xorg.conf.d/99-mouse-noaccel.conf
echo "   installed /etc/X11/xorg.conf.d/99-mouse-noaccel.conf"

echo "══ 2/3 wifi backend (iwd)"
backup /etc/NetworkManager/conf.d/wifi_backend.conf
install -Dm644 NetworkManager/conf.d/wifi_backend.conf /etc/NetworkManager/conf.d/wifi_backend.conf
if systemctl is-enabled wpa_supplicant.service >/dev/null 2>&1; then
    systemctl disable --now wpa_supplicant.service
    echo "   wpa_supplicant disabled (iwd takes over)"
fi
echo "   installed /etc/NetworkManager/conf.d/wifi_backend.conf"

echo "══ 3/3 display manager (LightDM + GTK greeter)"
if ! command -v lightdm >/dev/null 2>&1; then
    echo "   ! lightdm is not installed — skipping."
    echo "     sudo pacman -S --needed lightdm lightdm-gtk-greeter"
else
    backup /etc/lightdm/lightdm.conf.d/50-i3.conf
    install -Dm644 lightdm/50-i3.conf /etc/lightdm/lightdm.conf.d/50-i3.conf
    systemctl disable sddm.service 2>/dev/null || true
    systemctl enable lightdm.service
    echo "   installed /etc/lightdm/lightdm.conf.d/50-i3.conf, lightdm enabled"
fi

cat <<'EOF'

✔ System files in place.

Next:
  1) user files:      ./install.sh            (from the repo dir; needs stow)
  2) machine config:  cp examples/{local.conf,display.sh,machine.env} ~/.config/i3/
                      then edit for this box's outputs
  3) greeter on the wrong monitor?  see examples/lightdm-display-setup.sh
  4) keyboard layout (per machine): sudo localectl set-x11-keymap se pc105
  5) reboot and pick i3 in LightDM
EOF
