#!/bin/sh
# Install this setup by symlinking every package into $HOME with GNU Stow.
# Nothing is overwritten: stow aborts on a real file conflict (move it away first).

set -eu

cd "$(dirname "$0")"

if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is required:  sudo pacman -S stow" >&2
    exit 1
fi

# Everything used on either machine now lives in this repo — there is no separate
# "main dotfiles" repo any more (it was merged in here).
PACKAGES="i3 i3status rofi picom xprofile fastfetch fish gtk kitty local-bin redshift starship"

for pkg in $PACKAGES; do
    [ -d "$pkg" ] || { echo "missing package dir: $pkg" >&2; exit 1; }
    echo "==> stow $pkg"
    stow --restow --target="$HOME" "$pkg"
done

echo
# Root-owned files are not stowed (they live outside $HOME).
echo "Done. Remaining manual steps:"
echo "  1) mouse accel (root):  sudo cp system-files/99-mouse-noaccel.conf /etc/X11/xorg.conf.d/"
echo "  2) wifi backend (root): sudo cp system-files/NetworkManager/conf.d/wifi_backend.conf /etc/NetworkManager/conf.d/"
echo "       sudo systemctl disable --now wpa_supplicant.service   # iwd takes over (see packages.txt)"
echo "  3) display manager (root, not stowed):"
echo "       sudo pacman -S --needed lightdm lightdm-gtk-greeter"
echo "       sudo install -Dm644 system-files/lightdm/50-i3.conf /etc/lightdm/lightdm.conf.d/50-i3.conf"
echo "       sudo systemctl disable sddm.service ; sudo systemctl enable lightdm.service"
echo "     greeter on the wrong monitor / wrong refresh rate? -> examples/lightdm-display-setup.sh"
echo "     (see the comments in 50-i3.conf; 'active-monitor' is the one-line alternative)"
echo "  4) machine-specific config:"
echo "       cp examples/local.conf ~/.config/i3/local.conf      # workspace→output mapping"
echo "       cp examples/display.sh ~/.config/i3/display.sh      # xrandr (2nd monitor stays black without it)"
echo "       cp examples/machine.env ~/.config/i3/machine.env    # location, interfaces, screenshot dir"
echo "       chmod +x ~/.config/i3/display.sh"
echo "       -> then edit all three: xrandr --query | grep ' connected'"
echo "  5) make sure the packages in packages.txt are installed"
echo "       sudo pacman -S --needed $(grep -v '^#' packages.txt | tr '\n' ' ')"
echo "  6) sanity check:  i3 -C -c ~/.config/i3/config"
echo "  7) log out and pick i3 in LightDM"
