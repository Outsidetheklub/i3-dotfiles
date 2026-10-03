#!/bin/sh
# Root-side installation for i3-dotfiles: everything that lives OUTSIDE $HOME.
#
# Run this AFTER ./install.sh (which stows the user files):
#     sudo bash system-files/install-system.sh
#
# Idempotent, safe to re-run. Anything it would overwrite gets a copy next to it
# as <file>.bak-YYYY-MM-DD first. Nothing is deleted, nothing is uninstalled.
#
# It does NOT install packages — do that first (install.sh prints the exact
# command; packages.txt = Arch, packages.debian.txt = Debian).

set -eu
[ "$(id -u)" -eq 0 ] || { echo "run me with sudo:  sudo bash $0" >&2; exit 1; }
cd "$(dirname "$0")"

# Package-manager label, only used for the "you still need X" messages below.
if command -v pacman >/dev/null 2>&1; then
    PKG_INSTALL="sudo pacman -S --needed"
elif command -v apt-get >/dev/null 2>&1; then
    PKG_INSTALL="sudo apt install"
else
    PKG_INSTALL="(your package manager)"
fi

backup() {
    if [ -e "$1" ] && [ ! -L "$1" ]; then
        cp -a "$1" "$1.bak-$(date +%F)"
        echo "   backup: $1.bak-$(date +%F)"
    fi
}

echo "══ 1/5 mouse acceleration (Xorg)"
backup /etc/X11/xorg.conf.d/99-mouse-noaccel.conf
install -Dm644 99-mouse-noaccel.conf /etc/X11/xorg.conf.d/99-mouse-noaccel.conf
echo "   installed /etc/X11/xorg.conf.d/99-mouse-noaccel.conf"

echo "══ 2/5 wifi backend (iwd)"
backup /etc/NetworkManager/conf.d/wifi_backend.conf
install -Dm644 NetworkManager/conf.d/wifi_backend.conf /etc/NetworkManager/conf.d/wifi_backend.conf
if systemctl is-enabled wpa_supplicant.service >/dev/null 2>&1; then
    systemctl disable --now wpa_supplicant.service
    echo "   wpa_supplicant disabled (iwd takes over)"
fi
echo "   installed /etc/NetworkManager/conf.d/wifi_backend.conf"

echo "══ 3/5 services (NetworkManager, Bluetooth)"
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

echo "══ 4/5 display manager (LightDM + GTK greeter)"
if ! command -v lightdm >/dev/null 2>&1; then
    echo "   ! lightdm is not installed — skipping."
    echo "     $PKG_INSTALL lightdm lightdm-gtk-greeter"
else
    backup /etc/lightdm/lightdm.conf.d/50-i3.conf
    install -Dm644 lightdm/50-i3.conf /etc/lightdm/lightdm.conf.d/50-i3.conf
    systemctl disable sddm.service 2>/dev/null || true
    systemctl enable lightdm.service
    echo "   installed /etc/lightdm/lightdm.conf.d/50-i3.conf, lightdm enabled"
fi

echo "══ 5/5 keyboard layout (Swedish, < > | reachable on an ANSI board)"
# The X server resolves layouts ONLY from /usr/share/X11/xkb (the user dir
# ~/.config/xkb is visible to xkbcomp/libxkbcommon, not to Xorg) — so that is
# where the `seinans` variant has to live. Installing it system-wide also means
# X hands it to the keyboard on EVERY device add: a login-time script can't
# survive the keyboard re-enumerating (2.4G/BT switch, replug, re-pair), and used
# to leave the session on plain `se` with no way to get < > | back.
# `seinans` = stock `se` + the trio on the 3rd level; lv3:caps_switch makes Caps
# Lock that 3rd level (Caps + , . -).
backup /etc/X11/xorg.conf.d/00-keyboard.conf
install -Dm644 ../xkb/.config/xkb/symbols/seinans /usr/share/X11/xkb/symbols/seinans
echo "   installed /usr/share/X11/xkb/symbols/seinans"
localectl set-x11-keymap seinans pc105 "" lv3:caps_switch,terminate:ctrl_alt_bksp
echo "   set X11 keymap: seinans pc105 (lv3:caps_switch, terminate:ctrl_alt_bksp)"
# On an ISO keyboard plain `se` is enough (skip the seinans file above):
#   localectl set-x11-keymap se pc105

cat <<'EOF'

✔ System side done.

Still to do (see README):
  1) user files:      ./install.sh              (needs stow; run from the repo)
  2) machine config:  cp examples/{local.conf,display.sh,machine.env} ~/.config/i3/
                      then edit for this box's outputs (xrandr --query | grep connected)
  3) greeter on the wrong monitor?  see examples/lightdm-display-setup.sh
  4) browser (optional): Arch -> AUR zen-browser-bin; Debian -> Zen's apt repo or Flatpak
     (spotify is the same story: Spotify's apt repo / Flatpak on Debian)
  5) reboot and pick i3 in LightDM
EOF
