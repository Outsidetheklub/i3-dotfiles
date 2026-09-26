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
| `gtk/.config/mimeapps.list` | `~/.config/` | file associations: **sxiv** for images, **mpv** for video, zen for links/HTML. Apps may append to this — that shows up as a real diff, which is the point |
| `xprofile/.xprofile` | `~/.xprofile` | repaints the root window black (ghost login screen) + flatpak env |
| `system-files/99-mouse-noaccel.conf` | `/etc/X11/xorg.conf.d/` | the actual fix for mouse acceleration (needs root) |
| `system-files/NetworkManager/conf.d/wifi_backend.conf` | `/etc/NetworkManager/conf.d/` | wifi through iwd instead of wpa_supplicant (needs root) |
| `system-files/lightdm/50-i3.conf` | `/etc/lightdm/lightdm.conf.d/` | LightDM seat: i3 session + GTK greeter (needs root) |
| `system-files/install-system.sh` | — | all of the above in one `sudo bash`, plus it enables NetworkManager/Bluetooth and enables LightDM (idempotent, backs up) |
| `examples/local.conf` | `~/.config/i3/local.conf` | template for machine-specific i3 config |
| `examples/display.sh` | `~/.config/i3/display.sh` | template for machine-specific xrandr setup |
| `examples/lightdm-display-setup.sh` | `/usr/local/bin/` | template: pin the greeter's monitor + refresh rate (needs root) |
| `examples/machine.env` | `~/.config/i3/machine.env` | template: night-light location, interfaces, screenshot dir (everything machine-specific) |
| `examples/bookmarks` | `~/.config/gtk-3.0/bookmarks` | template: file-dialog sidebar shortcuts (personal, so never tracked) |

`examples/` is not stowed — it's reference material.

Everything now lives in **this** repo — it absorbed the older `dotfiles` repo
(GTK theme, fish, starship, fastfetch, redshift, kitty, and the
`local-bin` scripts). The old split was a headache: `~/.local/bin` pointed into one
repo while the i3 config lived in another.

**Also in here:** `gtk/`, `fish/`, `starship/`, `fastfetch/`,
`redshift/`, `kitty/`.

## Prerequisites

A base Arch install — that's all. Nothing graphical is assumed: the package list
below pulls in X, i3 and the login manager (`lightdm` depends on `xorg-server`,
which in turn brings the libinput input driver). The things in this table are the
ones a package list can't give you, because they're machine-specific:

| What | Command / note |
|---|---|
| Xorg | nothing to do — `lightdm` (in `packages.txt`) depends on `xorg-server`, which brings the server and the libinput driver |
| GPU driver | **NVIDIA:** `nvidia-open-dkms nvidia-utils lib32-nvidia-utils` — the *open* kernel modules (Turing and newer; required for Blackwell/RTX 50). `nvidia-container-toolkit` too if you use davincibox. **AMD/Intel:** `mesa` + the usual. `/etc/X11/xorg.conf.d/10-nvidia.conf` is per-machine and not tracked |
| Audio | `pipewire pipewire-pulse pipewire-alsa wireplumber` — in `packages.txt`; `pipewire-alsa` is what gives ALSA-only apps (DaVinci Resolve) sound |
| Keyboard layout | machine-specific: `localectl set-x11-keymap <layout> [model]` — writes `/etc/X11/xorg.conf.d/00-keyboard.conf`, so this repo never needs a `setxkbmap` line |
| AUR helper | `base-devel git` + an AUR helper for `zen-browser-bin` and `spotify-launcher` (the two AUR packages this setup wants) |
| Fonts | `noto-fonts` for the bar/terminal (`monospace`) and `ttf-firacode-nerd` for GTK apps — both in `packages.txt` |
| In a VM | no NVIDIA driver; use `mesa` + the VM's video driver (`qxl` or virtio-gpu) and, for QEMU/SPICE, `spice-vdagent`. Monitor names differ too — the VM X output is usually `Virtual-1`, so edit `local.conf` |

Everything the repo itself needs is in `packages.txt`:

```sh
sudo pacman -S --needed $(grep -v '^#' packages.txt | tr '\n' ' ')
```

### Starting from the Arch ISO (archinstall)

Choices that matter for this setup:

- **Profile:** *Minimal* — `packages.txt` supplies everything else. (The *i3*
  desktop profile also works and pre-installs X + i3 + a display manager, but the
  repo is written against the Minimal route.)
- **Network:** NetworkManager — the wifi rofi menu drives `nmcli`, so a
  systemd-networkd-only install won't have it (install it afterwards if you skip it).
- **Audio:** pipewire.
- **Extra packages:** `git`, so you can clone this repo.
- **Users:** your account in `wheel` with sudo, plus `video` (GPU apps expect it).
- **multilib:** enable if you want 32-bit libs (`lib32-nvidia-utils`, Steam).
- **Timezone / locale / keymap:** yours — but note the X11 keymap is a separate
  step (`localectl`, see above).

Reboot, log in, then follow [Install](#install). The repo is public, so
`git clone https://github.com/Outsidetheklub/i3-dotfiles.git` needs no SSH key.

## Install

What `install.sh` does and doesn't do — this is the bit that trips people up:

- **Does:** symlink all ~15 packages into `$HOME` with GNU Stow. Nothing else.
- **Doesn't:** install packages, create users, or touch `/etc`. It bails out if
  `stow` isn't installed yet. The root-side files live in `system-files/` and
  have their own script (see step 4).

The full order for a fresh machine:

```sh
# 1. packages (git + stow first: install.sh needs them)
sudo pacman -S --needed git stow
git clone git@github.com:Outsidetheklub/i3-dotfiles.git ~/i3-dotfiles
cd ~/i3-dotfiles
sudo pacman -S --needed $(grep -v '^#' packages.txt | tr '\n' ' ')   # + AUR: zen-browser-bin, spotify-launcher

# 2. user files
./install.sh

# 3. machine-specific config (edit the outputs for THIS box)
cp examples/local.conf examples/display.sh examples/machine.env ~/.config/i3/
chmod +x ~/.config/i3/display.sh

# 4. the root-side files + services, in one go
#    (mouse accel, iwd wifi backend, NetworkManager + bluetooth, LightDM)
sudo bash system-files/install-system.sh

# 5. keyboard layout for this machine, then reboot
sudo localectl set-x11-keymap se pc105
```

`install.sh` symlinks everything with GNU Stow (`stow --restow --target=$HOME`).
It refuses to clobber real files — if you already have e.g. `~/.config/i3/config`
as a real file (or symlinked by another dotfiles repo), move it away first:

```sh
stow -D <pkg>      # if some other repo already stows a package (e.g. an old dotfiles clone)
```

Then the root-side files — one script, idempotent, backs up anything it replaces:

```sh
sudo bash system-files/install-system.sh      # mouse accel + wifi backend + LightDM
```

(It only installs the three files above and enables LightDM. To do it by hand, or
to see exactly what it does, read the script — it's commented.)

Then the machine-specific config:

```sh
cp examples/local.conf  ~/.config/i3/local.conf      # then edit output names
cp examples/display.sh  ~/.config/i3/display.sh      # then edit, chmod +x
cp examples/machine.env ~/.config/i3/machine.env     # location, interfaces, screenshot dir
$EDITOR ~/.config/i3/local.conf ~/.config/i3/display.sh ~/.config/i3/machine.env
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

### Everything else machine-specific: `machine.env`

Scripts read these from `~/.config/i3/machine.env` (optional, **not tracked**, template
in `examples/machine.env`). No value is baked into the repo, and an unset value means
the script either auto-detects or stays quiet — so a stranger's clone behaves sensibly:

| Variable | Used by | Unset behaviour |
|---|---|---|
| `REDSHIFT_LOCATION` | night light | redshift isn't started at all (no wrong-location tint) |
| `INTERNAL_OUTPUT` | `projector.sh` | defaults to `eDP-1` |
| `WLAN_IFACE` | `network-rofi.sh` | defaults to `wlan0` |
| `SCREENSHOT_DIR` | `screenshot.sh` | XDG Pictures dir + `/Screenshots` |
| `NOTIFY_TIMEOUT` | rofi feedback (`network-rofi.sh`, `bluetooth-rofi.sh`, `screenshot.sh`) | 4s (screenshots: 2s) |

## Recreating this on another machine (e.g. the laptop)

```sh
# packages
sudo pacman -S --needed git stow
git clone git@github.com:Outsidetheklub/i3-dotfiles.git ~/i3-dotfiles
cd ~/i3-dotfiles
sudo pacman -S --needed $(grep -v '^#' packages.txt | tr '\n' ' ')   # + AUR: zen-browser-bin, spotify-launcher

# then deploy everything:
./install.sh
sudo bash system-files/install-system.sh
cp examples/local.conf ~/.config/i3/local.conf && cp examples/display.sh ~/.config/i3/display.sh
cp examples/machine.env ~/.config/i3/machine.env
chmod +x ~/.config/i3/display.sh
# edit all three for this machine's outputs, then log out and pick i3 in LightDM
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
