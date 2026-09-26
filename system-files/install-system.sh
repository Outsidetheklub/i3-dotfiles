#!/bin/sh
# Root-side installation for i3-dotfiles: everything that lives OUTSIDE $HOME.
#
# Run this AFTER ./install.sh (which stows the user files):
#     sudo bash system-files/install-system.sh
#
# Idempotent, safe to re-run. Anything it would overwrite gets a copy next to it
# as <file>.bak-YYYY-MM-DD first. Nothing is deleted, nothing is uninstalled.
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

echo "══ 1/4 mouse acceleration (Xorg)"
backup /etc/X11/xorg.conf.d/99-mouse-noaccel.conf
install -Dm644 99-mouse-noaccel.conf /etc/X11/xorg.conf.d/99-mouse-noaccel.conf
echo "   installed /etc/X11/xorg.conf.d/99-mouse-noaccel.conf"

echo "══ 2/4 wifi backend (iwd)"
backup /etc/NetworkManager/conf.d/wifi_backend.conf
install -Dm644 NetworkManager/conf.d/wifi_backend.conf /etc/NetworkManager/conf.d/wifi_backend.conf
if systemctl is-enabled wpa_supplicant.service >/dev/null 2>&1; then
    systemctl disable --now wpa_supplicant.service
    echo "   wpa_supplicant disabled (iwd takes over)"
fi
echo "   installed /etc/NetworkManager/conf.d/wifi_backend.conf"

echo "══ 3/4 services (NetworkManager, Bluetooth)"
if command -v NetworkManager >/dev/null 2>&1; then
    systemctl enable NetworkManager.service
    systemctl is-active NetworkManager.service >/dev/null 2>&1 || systemctl start NetworkManager.service
    echo "   NetworkManager enabled"
    # With the iwd backend NetworkManager drives iwd itself over D-Bus — the
    # standalone iwd.service must stay OFF or they fight over the device.
    if systemctl is-enabled iwd.service >/dev/null 2>&1; then
        systemctl disable --now iwd.service
        echo "   iwd.service disabled (NetworkManager drives iwd)"
    fi
else
    echo "   ! NetworkManager not installed — skipping (the wifi rofi menu needs nmcli)"
fi
if command -v bluetoothctl >/dev/null 2>&1; then
    systemctl enable bluetooth.service
    systemctl is-active bluetooth.service >/dev/null 2>&1 || systemctl start bluetooth.service
    echo "   bluetooth enabled"
else
    echo "   ! bluez-utils not installed — skipping (the bluetooth rofi menu needs it)"
fi

echo "══ 4/4 display manager (LightDM + GTK greeter)"
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

✔ System side done.

Still to do (see README):
  1) user files:      ./install.sh              (needs stow; run from the repo)
  2) machine config:  cp examples/{local.conf,display.sh,machine.env} ~/.config/i3/
                      then edit for this box's outputs (xrandr --query | grep connected)
  3) keyboard layout: sudo localectl set-x11-keymap se pc105
  4) greeter on the wrong monitor?  see examples/lightdm-display-setup.sh
  5) AUR browser (optional): paru/yay -> zen-browser-bin   (spotify-launcher is in the official repos)
  6) reboot and pick i3 in LightDM
EOF
