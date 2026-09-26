#!/bin/sh
# machine-backup.sh — snapshot the machine-specific CONFIG that i3-dotfiles
# deliberately doesn't track, so a wipe + reinstall doesn't lose the bits you
# can't reconstruct from memory:
#
#   * monitor names / workspace mapping / refresh-rate pin   (local.conf, display.sh)
#   * night-light location, interfaces, screenshot dir       (machine.env)
#   * LightDM + greeter setup, incl. the "greeter on the right
#     monitor" fix                                           (the LightDM files)
#   * Xorg keyboard + nvidia configs
#   * personal GTK bookmarks
#
# Usage:  machine-backup.sh [OUTDIR]        # default: ~/machine-backup-<date>
#
# NOT included, on purpose:
#   * packages — the repo's packages.txt covers the setup, and extra apps are
#     better re-added when you actually miss them than restored wholesale
#   * secrets and data — SSH/GPG keys, passwords, wallet, browser profiles,
#     your files. Those need their own backup.
#
# It only reads and copies; nothing on the system is modified.
set -eu

OUT=${1:-"$HOME/machine-backup-$(date +%F)"}
mkdir -p "$OUT/files/home/.config/i3" "$OUT/files/home/.config/gtk-3.0" \
         "$OUT/files/etc/xorg.conf.d" "$OUT/files/etc/lightdm/lightdm.conf.d" \
         "$OUT/files/usr-local-bin"

copy() { # copy <src> <destdir>
    [ -e "$1" ] || return 0
    if cp -a "$1" "$2/" 2>/dev/null; then echo "  + $1"; else echo "  ! could not read $1"; fi
}

echo "==> machine-specific config"
copy "$HOME/.config/i3/local.conf"                    "$OUT/files/home/.config/i3"
copy "$HOME/.config/i3/display.sh"                    "$OUT/files/home/.config/i3"
copy "$HOME/.config/i3/machine.env"                   "$OUT/files/home/.config/i3"
copy "$HOME/.config/gtk-3.0/bookmarks"                "$OUT/files/home/.config/gtk-3.0"
copy /etc/X11/xorg.conf.d/10-nvidia.conf              "$OUT/files/etc/xorg.conf.d"
copy /etc/X11/xorg.conf.d/00-keyboard.conf            "$OUT/files/etc/xorg.conf.d"
copy /etc/X11/xorg.conf.d/99-mouse-noaccel.conf       "$OUT/files/etc/xorg.conf.d"
copy /etc/NetworkManager/conf.d/wifi_backend.conf     "$OUT/files/etc"
copy /etc/lightdm/lightdm.conf.d/50-i3.conf           "$OUT/files/etc/lightdm/lightdm.conf.d"
copy /etc/lightdm/lightdm.conf.d/60-display-setup.conf "$OUT/files/etc/lightdm/lightdm.conf.d"
copy /etc/lightdm/lightdm-gtk-greeter.conf            "$OUT/files/etc/lightdm"
copy /usr/local/bin/lightdm-display-setup.sh          "$OUT/files/usr-local-bin"

cat > "$OUT/README.md" <<'EOF'
# Machine configuration backup — how to restore

The i3-dotfiles repo restores the *setup* (packages.txt → install.sh →
system-files/install-system.sh). This folder restores the machine-specific
pieces it deliberately leaves out.

```sh
# 1. user config
cp files/home/.config/i3/local.conf files/home/.config/i3/display.sh \
   files/home/.config/i3/machine.env   ~/.config/i3/
chmod +x ~/.config/i3/display.sh
cp files/home/.config/gtk-3.0/bookmarks ~/.config/gtk-3.0/

# 2. root-side, per-machine files
sudo cp files/etc/xorg.conf.d/*            /etc/X11/xorg.conf.d/
sudo cp files/etc/wifi_backend.conf        /etc/NetworkManager/conf.d/
sudo cp files/etc/lightdm/lightdm.conf.d/* /etc/lightdm/lightdm.conf.d/
sudo cp files/etc/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/
sudo install -Dm755 files/usr-local-bin/lightdm-display-setup.sh \
        /usr/local/bin/lightdm-display-setup.sh

# 3. keyboard layout for the new machine, then reboot
sudo localectl set-x11-keymap se pc105
```

Packages: `packages.txt` from the repo. For anything else, add it when you notice
it's missing — there's no value in restoring an apps list wholesale.
EOF
echo "  + README.md (short restore checklist)"

echo
echo "Machine config saved to: $OUT"
echo "Stash it somewhere private (cloud/USB). Re-run it whenever the config changes"
echo "(monitors, refresh rate, night-light location, greeter setup…)."
