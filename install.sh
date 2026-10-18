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
PACKAGES="i3 i3status picom rofi xprofile xkb fastfetch fish gtk kitty local-bin redshift starship spotify-player"

for pkg in $PACKAGES; do
    [ -d "$pkg" ] || { echo "missing package dir: $pkg" >&2; exit 1; }
    # local-bin and spotify-player own directories that apps also WRITE into:
    # local-bin -> ~/.local/bin (siblings ~/.local/share, ~/.local/state stay
    # busy), spotify-player -> ~/.config/spotify-player (the app creates its own
    # app.toml there on first run). Without --no-folding, stow would fold the
    # parent directory into a symlink back into this repo, and everything those
    # apps write would land here as stray untracked files. Keep the real
    # directories and link only the files the repo actually tracks.
    extra=""
    case "$pkg" in
        local-bin|spotify-player) extra="--no-folding" ;;
    esac
    echo "==> stow $pkg"
    stow --restow $extra --target="$HOME" "$pkg"
done

# Thunar / GTK sidebar bookmarks. The file is deliberately machine-local
# (gtk/.stow-local-ignore keeps it out of the repo) because every line contains
# an absolute $HOME path: a copy taken from another machine leaves pinned
# folders pointing at /home/<someone-else>/Documents, which Thunar lists and
# then refuses to open. So build it here, from the XDG user dirs — that also
# gets localized folder names right (Dokument on a Swedish box, Documents on an
# English one) and skips folders that don't exist. An existing file is left
# alone unless it points at a home directory that isn't yours.
bookmarks="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/bookmarks"
write_bookmarks=0
if [ ! -e "$bookmarks" ]; then
    write_bookmarks=1
elif grep -E '^file:///home/' "$bookmarks" | grep -qvF "file://$HOME/"; then
    write_bookmarks=1
fi
if [ "$write_bookmarks" -eq 1 ]; then
    echo "==> GTK bookmarks ($bookmarks)"
    mkdir -p "$(dirname "$bookmarks")"
    tmp="$bookmarks.$$"
    : > "$tmp"
    for key in PICTURES DOWNLOAD DOCUMENTS MUSIC VIDEOS; do
        dir=""
        if command -v xdg-user-dir >/dev/null 2>&1; then
            dir=$(xdg-user-dir "$key" 2>/dev/null || true)
        fi
        # xdg-user-dir prints $HOME for an undefined key -> skip that and
        # any folder that simply isn't there on this machine.
        [ -n "$dir" ] && [ "$dir" != "$HOME" ] && [ -d "$dir" ] || continue
        # Bookmark lines are URIs, so spaces (and, on a Swedish box, å/ä/ö)
        # need percent-encoding. python3 is already a dependency above; the
        # sed branch is the fallback for spaces only.
        uri=""
        if command -v python3 >/dev/null 2>&1; then
            uri=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$dir" 2>/dev/null || true)
        fi
        [ -n "$uri" ] || uri="file://$(printf '%s' "$dir" | sed 's/ /%20/g')"
        printf '%s\n' "$uri" >> "$tmp"
    done
    # nothing to pin at all? then don't create an empty file either
    if [ -s "$tmp" ]; then mv "$tmp" "$bookmarks"; else rm -f "$tmp"; fi
fi

# Monochrome cursor theme. Regenerates Breeze_Light as ~/.local/share/icons/
# breeze-mono-light (every coloured cursor greyscaled) and points all six cursor
# settings at it. Needs python (stdlib only) + breeze-cursors (the source theme).
# Non-fatal on purpose: a cursor theme should never break an install.
if command -v python3 >/dev/null 2>&1 && [ -d /usr/share/icons/Breeze_Light ]; then
    echo "==> mono-cursor (monochrome Breeze cursor theme)"
    "$HOME/.local/bin/mono-cursor" || \
        echo "   !! mono-cursor failed - cursor theme NOT applied (safe to re-run later)" >&2
else
    echo "==> skipping mono-cursor: needs 'python' + 'breeze-cursors' (see packages.txt)"
fi

# Icon theme. gtk/.config/gtk-*/settings.ini names Papirus-Dark, but stock
# Papirus folders are blue - the black-and-white look needs them white, and that
# recolour rewrites /usr/share/icons/Papirus-Dark, so it cannot be a tracked
# config file. Redo it here instead (AUR package papirus-folders-git, see
# packages.txt). This step genuinely needs root, so it uses plain `sudo` and
# asks for your password. Do NOT use `sudo -n` here: with no cached credential
# it fails silently and the folders just stay blue (the whole point of the
# step). Already-white folders are skipped so re-runs don't prompt for nothing.
if command -v papirus-folders >/dev/null 2>&1; then
    if [ "$(papirus-folders -l 2>/dev/null | sed -n 's/^[[:space:]]*>[[:space:]]*//p')" = white ]; then
        echo "==> papirus-folders: folders already white on Papirus-Dark"
    else
        echo "==> papirus-folders (white folders on Papirus-Dark) - root required"
        if ! sudo papirus-folders -C white --theme Papirus-Dark; then
            echo "   !! recolour failed or was cancelled - run later: sudo papirus-folders -C white --theme Papirus-Dark" >&2
        fi
    fi
else
    echo "==> skipping papirus-folders: needs 'papirus-icon-theme' + 'papirus-folders-git' (see packages.txt)"
fi

# Terminus Bold under its own family name (local-bin/terminus-bold). The browser's
# font settings ask for "Terminess Bold Mono": Firefox resolves a family against
# the list of installed families, so a fontconfig alias is invisible to it — the
# Bold TTF gets a renamed copy instead. Needs uv (fetches fontTools) + Terminus.
if [ -x "$HOME/.local/bin/terminus-bold" ]; then
    echo "==> terminus-bold (Terminus Bold as its own family)"
    "$HOME/.local/bin/terminus-bold" || \
        echo "   !! terminus-bold failed - the browser falls back to Regular Terminus" >&2
else
    echo "==> skipping terminus-bold: not stowed yet"
fi

# gamepad-idle-guard — keep the display awake while a gamepad is in use (X11 only
# counts keyboard/mouse as activity, so DPMS blanked mid-game). The source is
# src/gamepad-idle-guard.c; build it into ~/.local/bin here. Needs a C compiler +
# the libX11/libXext/libXss headers, and membership in the `input` group to read
# /dev/input (see README).
if [ -f src/gamepad-idle-guard.c ]; then
    echo "==> gamepad-idle-guard (build)"
    mkdir -p "$HOME/.local/bin"
    if command -v cc >/dev/null 2>&1 && \
       cc -O2 -o "$HOME/.local/bin/gamepad-idle-guard" \
           src/gamepad-idle-guard.c -lX11 -lXss -lXext; then
        echo "   built ~/.local/bin/gamepad-idle-guard"
    else
        echo "   !! build failed — needs a C compiler + libX11/libXext/libXss headers (see packages.txt)" >&2
    fi
fi

# awake-toggle — keep the screen from blanking until toggled back ($mod+Shift+a).
# Source is src/awake-toggle.c; same libs as the gamepad guard (no libXss needed).
if [ -f src/awake-toggle.c ]; then
    echo "==> awake-toggle (build)"
    mkdir -p "$HOME/.local/bin"
    if command -v cc >/dev/null 2>&1 && \
       cc -O2 -o "$HOME/.local/bin/awake-toggle" \
           src/awake-toggle.c -lX11 -lXext; then
        echo "   built ~/.local/bin/awake-toggle"
    else
        echo "   !! build failed — needs a C compiler + libX11/libXext headers (see packages.txt)" >&2
    fi
fi
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
echo "       grep -v '^#' packages.txt | xargs sudo pacman -S --needed   # works in bash + fish"
echo "  6) sanity check:  i3 -C -c ~/.config/i3/config"
echo "  7) log out and pick i3 in LightDM"
echo "     icons: if install.sh couldn't recolour them, run"
echo "       sudo papirus-folders -C white --theme Papirus-Dark   # Papirus folders, white"
