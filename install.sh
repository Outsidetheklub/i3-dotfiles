#!/bin/sh
# Install this setup by symlinking every package into $HOME with GNU Stow.
# Nothing is overwritten: stow aborts on a real file conflict (move it away first).

set -eu

cd "$(dirname "$0")"

if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is required:  sudo pacman -S stow" >&2
    exit 1
fi

# NOTE: kitty is intentionally NOT here — its config lives in my main dotfiles repo
# (terminal config shared with the laptop). This repo only needs kitty installed.
# NOTE: no local-bin here either — ~/.local/bin is owned by the main dotfiles repo
# (scripts: power-menu.sh, bluetooth-rofi.sh, …).
PACKAGES="i3 i3status rofi dunst picom xprofile"

for pkg in $PACKAGES; do
    [ -d "$pkg" ] || { echo "missing package dir: $pkg" >&2; exit 1; }
    echo "==> stow $pkg"
    stow --restow --target="$HOME" "$pkg"
done

echo
echo "Done. Remaining manual steps:"
echo "  1) mouse accel (root):  sudo cp system-files/99-mouse-noaccel.conf /etc/X11/xorg.conf.d/"
echo "  2) machine-specific config:"
echo "       cp examples/local.conf ~/.config/i3/local.conf    # workspace→output mapping"
echo "       cp examples/display.sh ~/.config/i3/display.sh    # xrandr (2nd monitor stays black without it)"
echo "       chmod +x ~/.config/i3/display.sh"
echo "       -> then edit both: xrandr --query | grep ' connected'"
echo "  3) make sure the packages in packages.txt are installed"
echo "  4) sanity check:  i3 -C -c ~/.config/i3/config"
echo "  5) log out and pick i3 in SDDM"
