# i3-dotfiles

My X11/i3 desktop setup. Deliberately minimal and **un-themed**: plain black,
default fonts, no effects. It's the stable fallback I keep around for when
Wayland/niri misbehaves, so it's built for things that must not break —
monitors, mouse acceleration, keybinds — not for looks.

Machine-specific bits (monitor names, workspace→output mapping) are **not
tracked here** — they live in `~/.config/i3/local.conf` + `~/.config/i3/display.sh`,
so the same repo works on the desktop and the laptop. Templates are in `examples/`.

## What's in here

| Path | Goes to | What it does |
|---|---|---|
| `i3/.config/i3/config` | `~/.config/i3/` | the whole WM config — keybinds, autostart. Includes `local.conf` for machine-specific parts |
| `i3/.config/i3/startup.sh` | `~/.config/i3/` | polkit agent, gamepad idle guard, calls `display.sh` if present |
| `i3/.config/i3/mouse-watch.sh` | `~/.config/i3/` | watchdog that keeps libinput mouse acceleration off (games reset it) |
| `i3status/.config/i3status/config` | `~/.config/i3status/` | bar modules: wifi, disk free, RAM used/available, clock |
| `rofi/.config/rofi/config.rasi` | `~/.config/rofi/` | launcher — black, centered, no icons. Also used by the power menu |
| `picom/.config/picom/picom.conf` | `~/.config/picom/` | compositing + vsync only, no shadows/fading/transparency |
| `local-bin/.local/bin/*` | `~/.local/bin/` | scripts: power menu (`$mod+Escape`), Bluetooth menu (`$mod+Shift+b`), wifi menu (`$mod+Shift+n`), screenshots (`Print`, `$mod+Shift+s`), projector, mouse-to-focused, … |
| `xprofile/.xprofile` | `~/.xprofile` | repaints the root window black (ghost login screen) + flatpak env |
| `system-files/99-mouse-noaccel.conf` | `/etc/X11/xorg.conf.d/` | the actual fix for mouse acceleration (needs root) |
| `system-files/lightdm/50-i3.conf` | `/etc/lightdm/lightdm.conf.d/` | LightDM seat: i3 session + GTK greeter (needs root) |
| `examples/local.conf` | `~/.config/i3/local.conf` | template for machine-specific i3 config |
| `examples/display.sh` | `~/.config/i3/display.sh` | template for machine-specific xrandr setup |
| `examples/lightdm-display-setup.sh` | `/usr/local/bin/` | template: pin the greeter's monitor + refresh rate (needs root) |

`examples/` is not stowed — it's reference material.

Everything now lives in **this** repo — it absorbed the older `dotfiles` repo
(GTK theme, fish, starship, fastfetch, redshift, kitty, and the
`local-bin` scripts). The old split was a headache: `~/.local/bin` pointed into one
repo while the i3 config lived in another.

**Also in here:** `gtk/`, `fish/`, `starship/`, `fastfetch/`,
`redshift/`, `kitty/`.

## Install

```sh
git clone git@github.com:Outsidetheklub/i3-dotfiles.git ~/i3-dotfiles
cd ~/i3-dotfiles
./install.sh
```

`install.sh` symlinks everything with GNU Stow (`stow --restow --target=$HOME`).
It refuses to clobber real files — if you already have e.g. `~/.config/i3/config`
as a real file (or symlinked by another dotfiles repo), move it away first:

```sh
stow -D <pkg>      # if some other repo already stows a package (e.g. an old dotfiles clone)
```

Then the manual steps:

```sh
# 1. mouse acceleration (root, not stowed)
sudo cp system-files/99-mouse-noaccel.conf /etc/X11/xorg.conf.d/

# 2. display manager (root, not stowed)
sudo pacman -S --needed lightdm lightdm-gtk-greeter
sudo install -Dm644 system-files/lightdm/50-i3.conf /etc/lightdm/lightdm.conf.d/50-i3.conf
sudo systemctl disable sddm.service && sudo systemctl enable lightdm.service

# 3. machine-specific config
cp examples/local.conf  ~/.config/i3/local.conf     # then edit output names
cp examples/display.sh  ~/.config/i3/display.sh     # then edit, chmod +x
$EDITOR ~/.config/i3/local.conf ~/.config/i3/display.sh
```

Packages: `packages.txt` (`sudo pacman -S --needed $(grep -v '^#' packages.txt | tr '\n' ' ')`).

## Machine-specific config

`~/.config/i3/config` ends with `include ~/.config/i3/local.conf`. That file is
**not tracked**, so pulling updates never conflicts, and a machine with no
`local.conf` still starts i3 fine (it just gets no output bindings — verified).

`local.conf` holds:
- `workspace N output <name>` lines
- `$mod+Shift+Left/Right` move-to-output binds
- anything else that's machine-only

`display.sh` holds the `xrandr` calls. **This is the one that actually matters:**
neither i3 nor X enables extra outputs, so without it a second monitor stays
black no matter what the i3 config says.

Find the names first: `xrandr --query | grep ' connected'`.

## Recreating this on another machine (e.g. the laptop)

```sh
# packages
sudo pacman -S --needed git stow
git clone git@github.com:Outsidetheklub/i3-dotfiles.git ~/i3-dotfiles
cd ~/i3-dotfiles
sudo pacman -S --needed $(grep -v '^#' packages.txt | tr '\n' ' ')   # + AUR: zen-browser-bin, spotify-launcher

# then deploy everything:
./install.sh
sudo cp system-files/99-mouse-noaccel.conf /etc/X11/xorg.conf.d/
sudo pacman -S --needed lightdm lightdm-gtk-greeter
sudo install -Dm644 system-files/lightdm/50-i3.conf /etc/lightdm/lightdm.conf.d/50-i3.conf
sudo systemctl enable lightdm.service
cp examples/local.conf ~/.config/i3/local.conf && cp examples/display.sh ~/.config/i3/display.sh
chmod +x ~/.config/i3/display.sh
# edit both for this machine's outputs, then log out and pick i3 in LightDM
# greeter on the wrong monitor? install examples/lightdm-display-setup.sh (see its header)
# check first: i3 -C -c ~/.config/i3/config
```

Laptop extras worth adding:
- **Battery in the bar** (dropped here, it's a desktop): add
  `order += "battery all"` and `battery all { format = "%status %percentage %remaining" }`
  to `~/.config/i3status/config`.
- **Projector** (`$mod+Shift+p` / `$mod+Shift+x`): the two binds are commented at the
  bottom of `i3/.config/i3/config`; the script is `local-bin/.local/bin/projector.sh`.

## Keybinds

`$mod` = Super.

| Keys | Action |
|---|---|
| `$mod+Return` / `$mod+b` | kitty / browser |
| `$mod+e` / `$mod+p` | Thunar / pavucontrol |
| `$mod+Shift+b` | Bluetooth menu (rofi → bluetoothctl) |
| `$mod+space` / `$mod+Escape` | rofi launcher / rofi power menu |
| `$mod+h/j/k/l` | focus (arrows too) |
| `$mod+Shift+h/j/k/l` | move window |
| `$mod+1..0` | workspace 1–10 (`$mod+Shift+1..0` moves container) |
| `$mod+f`, `$mod+q`, `$mod+Shift+space` | fullscreen, kill, floating |
| `$mod+r` | resize mode (h/j/k/l, Enter/Esc to exit) |
| `$mod+Shift+c` / `$mod+Shift+r` | reload / restart i3 |
| `$mod+m` | Spotify |
| `Print` / `$mod+Shift+s` / `$mod+Print` | screenshot → file **and** clipboard: full / region / window (`$mod+Shift+Print` = click one) |
| `Ctrl+Print` / `$mod+Ctrl+s` / `$mod+Ctrl+Print` | same, **clipboard only** (no file; `$mod+Ctrl+Shift+Print` = click one) |

## Things worth knowing

- **Autostart is duplicate-guarded**: `picom`/`redshift` are started with
  `pgrep -x <name> || <name>`, and `mouse-watch.sh` has a `flock` singleton, so
  `$mod+Shift+r` brings back anything that died without stacking up copies.
- **The bar is at the bottom** (`position bottom`), with a black/grey `colors`
  block because i3's stock blue for the focused workspace doesn't fit.
- **No Nerd Fonts are required** — the power menu uses plain words, so default
  `monospace` everywhere works.
- Wallpaper: none, solid black (`xsetroot`). Uncomment the `feh` line in
  `i3/.config/i3/startup.sh` if you want an image.
- Mouse accel has two layers on purpose: the driver-level `99-mouse-noaccel.conf`
  (permanent, all devices) plus the `mouse-watch.sh` watchdog, because Proton
  games reset the setting at runtime.
