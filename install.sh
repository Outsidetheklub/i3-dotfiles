#!/bin/sh
# Install this setup by symlinking every package into $HOME with GNU Stow.
# Nothing is overwritten: stow aborts on a real file conflict (move it away first).

set -eu

cd "$(dirname "$0")"

if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is required:  sudo pacman -S stow" >&2
    exit 1
fi

PACKAGES="i3 i3status rofi dunst picom kitty local-bin xprofile"

for pkg in $PACKAGES; do
    [ -d "$pkg" ] || { echo "missing package dir: $pkg" >&2; exit 1; }
    echo "==> stow $pkg"
    stow --restow --target="$HOME" "$pkg"
done

echo
echo "Done. Remaining manual steps:"
echo "  1) mouse accel (root):  sudo cp system-files/99-mouse-noaccel.conf /etc/X11/xorg.conf.d/"
echo "  2) make sure the packages in packages.txt are installed"
echo "  3) check the monitor names in i3/.config/i3/config + startup.sh (DP-4 / HDMI-0)"
echo "  4) log out and pick i3 in SDDM"
