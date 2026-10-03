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
| `local-bin/.local/bin/*` | `~/.local/bin/` | scripts: power menu (`$mod+Escape`), Bluetooth menu (`$mod+Shift+b`), wifi menu (`$mod+Shift+n`), screenshots (`Print`, `$mod+Shift+s`), projector, mouse-to-focused, monochrome cursor builder (`mono-cursor`), the distro-neutral polkit agent (`polkit-agent`), … |
| `gtk/.config/mimeapps.list` | `~/.config/` | file associations: **sxiv** for images, **mpv** for video, zen for links/HTML. Apps may append to this — that shows up as a real diff, which is the point |
| `xprofile/.xprofile` | `~/.xprofile` | repaints the root window black (ghost login screen), cursor env, flatpak env, and (as a fallback) the ANSI keyboard layout |
| `system-files/99-mouse-noaccel.conf` | `/etc/X11/xorg.conf.d/` | the actual fix for mouse acceleration (needs root) |
| `system-files/NetworkManager/conf.d/wifi_backend.conf` | `/etc/NetworkManager/conf.d/` | wifi through iwd instead of wpa_supplicant (needs root) |
| `system-files/lightdm/50-i3.conf` | `/etc/lightdm/lightdm.conf.d/` | LightDM seat: i3 session + GTK greeter (needs root) |
| `system-files/install-system.sh` | — | all of the above in one `sudo bash`, plus it enables NetworkManager/Bluetooth and enables LightDM (idempotent, backs up) |
| `packages.txt` / `packages.debian.txt` | — | the package lists (Arch / Debian names) — `install.sh` detects the host and points at the right one |
| `src/gamepad-idle-guard.c` | (compiled into `~/.local/bin/`) | X11 helper that keeps the screen awake while a gamepad is in use — `install.sh` builds it |
| `examples/local.conf` | `~/.config/i3/local.conf` | template for machine-specific i3 config |
| `examples/display.sh` | `~/.config/i3/display.sh` | template for machine-specific xrandr setup (`examples/display-laptop-7490.sh` is the 7490's known-good version) |
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

### Fonts

The desktop is **Terminus** (`font_family` in `kitty/`, `font pango:…` in
`i3/`, `font:` in `rofi/`, `gtk-font-name` in `gtk/`, `font-family` in
`gtk/.config/gtk-3.0/thunar.css`). It renders smaller than Noto/FiraCode at
equal pt, so every size here is ~2pt larger than the font it replaced.

⚠️ Terminus Regular's stems are exactly **1px** — crisp at Thunar's 12pt, thin
at browser text sizes. So two places ask for the Bold face instead: the **i3bar**
(`font pango:Terminess Nerd Font Mono Bold 13`, since pango understands style
keywords) and the **browser**, whose four font prefs point at
**"Terminess Bold Mono"**.

That name is real, but *generated*: `local-bin/.local/bin/terminus-bold` writes a
renamed copy of the Bold TTF (`TerminessBoldMono-Regular.ttf`, family
"Terminess Bold Mono", style Regular — same glyphs, new name table). ⚠️ It has to
be a real font: Firefox resolves a requested family against fontconfig's **list of
installed families**, so the obvious shortcut — an alias in
`~/.config/fontconfig/fonts.conf` — is silently ignored by the browser (pattern
rewrites never make it into that list; tried both `target="pattern"` and
`target="font"` on 2026-09-29, no dice). Re-run `terminus-bold` after updating
Terminus; `install.sh` does it for you.

The font itself comes from `ttf-terminus-nerd` (family
`Terminess Nerd Font Mono`); `terminus-bold` writes the generated Bold family to
`~/.local/share/fonts/terminess/` — the only per-user font file in the setup.

⚠️ **The browser's font settings are per-profile and not tracked by the repo**, so
on a second machine set them by hand: Zen → Settings → font, or drop this in
`~/.config/zen/<profile>/user.js` (it re-applies at every start):

```js
user_pref("font.name.sans-serif.x-western", "Terminess Bold Mono");
user_pref("font.name.serif.x-western",      "Terminess Bold Mono");
user_pref("font.name.monospace.x-western",  "Terminess Bold Mono");
user_pref("theme.custom_uifont.custom",     "Terminess Bold Mono");
```

Sanity check the family is visible to apps (`fc-match` is not enough — it resolves
aliases a browser will ignore): `fc-list :family="Terminess Bold Mono"`.

### Cursor theme

One thing in this setup *is* themed, because the alternative is worse: the cursor.
Breeze's cursor set is the least intrusive one around, but its busy spinner is
KDE-blue and a few other cursors (`help`, `no-drop`, `size-*`, `copy`, …) are
coloured too — loud on a black-and-white desktop.

`local-bin/.local/bin/mono-cursor` fixes that by **generating** a corrected theme
rather than shipping one:

- clones `Breeze_Light` to `~/.local/share/icons/breeze-mono-light` with every
  coloured cursor greyscaled (colour only, **never resampled** — native sizes,
  hotspots and animation frames are preserved bit-for-bit);
- writes all six places a cursor setting can hide: `~/.xprofile`
  (`XCURSOR_THEME`/`XCURSOR_SIZE`), GTK 3 + 4 `settings.ini`, `kcminputrc`,
  `~/.local/share/icons/default/index.theme` and `gsettings`;
- deterministic + idempotent, and it writes *through* the stow symlinks instead
  of replacing them.

`install.sh` runs it for you; re-run it by hand after a Breeze update. Changes
only take effect after **logging out and back in** (`XCURSOR_THEME` must exist
before i3 starts, so `i3-msg restart` isn't enough).

⚠️ **Don't "fix" the size to 32.** Breeze declares its sizes at 3/4 of the real
pixel size, so `XCURSOR_SIZE=24` renders a 32px cursor and 32 would give 40px.

### Icon theme

`gtk/.config/gtk-{3.0,4.0}/settings.ini` name **Papirus-Dark** (Adwaita's
blue folder icons were the last colour left in GTK). One wrinkle: Papirus ships
its folders *blue*, and the white-on-black desktop wants them white — so the
folder colour is set with `papirus-folders`, which **rewrites
`/usr/share/icons/Papirus-Dark`** rather than reading a config file:

```sh
sudo papirus-folders -C white --theme Papirus-Dark   # papirus-folders-git (AUR)
papirus-folders -l                                   # all available colours
```

Because that's system state and not a dotfile, `install.sh` re-applies it on a
new box (it tries `sudo -n` first so an unattended run can't hang on a password
prompt — otherwise it prints the command). Re-run it after a Papirus update,
which restores the packaged files. Note the flip side, and the reason the
selection is a *white block*: Papirus-Dark icons are light by design, so they
disappear on the selected row — that's expected, not a bug.

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
| Keyboard layout | Swedish, with `<` `>` `|` fixed for an ANSI board: `install-system.sh` drops the `seinans` variant into `/usr/share/X11/xkb` and runs `localectl set-x11-keymap seinans pc105 "" lv3:caps_switch,terminate:ctrl_alt_bksp`. That default is what X applies on every keyboard (re)connect, so no `setxkbmap` line is needed |
| Gamepad guard | the user must be in the **`input`** group, so `gamepad-idle-guard` can read `/dev/input` and notice controller activity: `sudo usermod -aG input $USER`, then re-login |
| AUR helper | only for two things: the browser (`zen-browser-bin`) and the folder recolour (`papirus-folders-git`) — `base-devel git` + an AUR helper (paru/yay), 3-line recipe below |
| Fonts | `noto-fonts` for the bar/terminal (`monospace`) and `ttf-firacode-nerd` for GTK apps — both in `packages.txt` |
| Cursor theme | nothing to do — `install.sh` builds the monochrome Breeze set itself. `breeze-cursors` (the source theme) + `python` are in `packages.txt` for that |
| Icons | `papirus-icon-theme` (official) + `papirus-folders-git` (AUR) are in `packages.txt`; `install.sh` recolours the folders white, because that rewrites `/usr/share/icons` instead of reading a config file |
| In a VM | no NVIDIA driver; use `mesa` + the VM's video driver (`qxl` or virtio-gpu) and, for QEMU/SPICE, `spice-vdagent`. Monitor names differ too — the VM X output is usually `Virtual-1`, so edit `local.conf` |

Everything the repo itself needs is in `packages.txt`:

```sh
grep -v '^#' packages.txt | xargs sudo pacman -S --needed
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

> **Verified 2026-09-26:** a fresh `archinstall` (minimal profile) in a QEMU VM
> (SPICE + virtio-vga), followed by clone → `packages.txt` → `./install.sh` →
> `sudo bash system-files/install-system.sh`, came up with i3, the bar, rofi,
> screenshots (maim/slop) and the GTK theme all working. The steps below are that
> exact sequence.

What `install.sh` does and doesn't do — this is the bit that trips people up:

- **Does:** symlink all ~15 packages into `$HOME` with GNU Stow, then build +
  activate the monochrome cursor theme (`mono-cursor`; skipped with a note if
  `python`/`breeze-cursors` are missing) and recolour the Papirus folders white
  (`papirus-folders`; prints the command instead if it can't get root).
- **Doesn't:** install packages, create users, or touch `/etc`. It bails out if
  `stow` isn't installed yet. The root-side files live in `system-files/` and
  have their own script (see step 4).

The full order for a fresh machine:

```sh
# 1. packages (git + stow first: install.sh needs them)
#    on Debian: packages.debian.txt + `sudo apt install` — see "Debian (apt) machines"
sudo pacman -S --needed git stow
git clone git@github.com:Outsidetheklub/i3-dotfiles.git ~/i3-dotfiles
cd ~/i3-dotfiles
grep -v '^#' packages.txt | xargs sudo pacman -S --needed   # + AUR: zen-browser-bin (see below)

# 2. user files
./install.sh

# 3. machine-specific config (edit the outputs for THIS box)
cp examples/local.conf examples/display.sh examples/machine.env ~/.config/i3/
chmod +x ~/.config/i3/display.sh

# 4. the root-side files + services, in one go
#    (mouse accel, iwd wifi backend, NetworkManager + bluetooth, LightDM,
#     keyboard layout)
sudo bash system-files/install-system.sh

# 5. reboot and pick i3 in LightDM
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

Packages: `packages.txt` (`grep -v '^#' packages.txt | xargs sudo pacman -S --needed`).

### Optional: the AUR packages (the browser + the folder recolour)

`packages.txt` covers everything that lives in the official repos, including
`spotify-launcher` and `papirus-icon-theme`. Two packages are AUR — the browser
(`$mod+b`) and `papirus-folders-git` (the white folders, see "Icon theme"
above) — and installing those needs an AUR helper; bootstrap one like this:

```sh
sudo pacman -S --needed base-devel git          # build tools

git clone https://aur.archlinux.org/paru.git /tmp/paru
cd /tmp/paru && makepkg -si                     # no sudo: makepkg refuses to run as root

paru -S zen-browser-bin papirus-folders-git        # browser + folder recolour
```

`yay` works identically — swap the clone URL and the rest is the same. Skip the
browser if you don't want it; skip `papirus-folders-git` only if you're happy
with blue folders.

> On CachyOS repos both `paru` and `zen-browser-bin` are mirrored, so there it's
> just `sudo pacman -S paru zen-browser-bin` (`papirus-folders-git` is mirrored
> too — `paru -S papirus-folders-git` works without building).

## Debian (apt) machines

The setup is distro-neutral — the stow packages are plain config, and both
installers detect the package manager — so a Debian machine runs the same repo
with different package names. This section is the whole path: install Debian,
then this repo.

### 1. Install Debian

Get the **netinst** image (`debian-<version>-amd64-netinst.iso`) — despite the
name it's the "minimal" one: the installer plus a very basic system, with
anything else pulled from the network. Don't bother with the CD/DVD sets. Same
image for a VM.

Boot it and pick **"Graphical expert install"** (or *Advanced options → expert
install*). Expert mode gives you the prompts that matter below instead of
fighting the defaults.

**Partitioning** — the one step to slow down for. "Guided – use entire disk" is
fine on a throwaway VM; on real hardware pick "Manual" and use the same shape as
the Arch box: an **EFI System Partition** (vfat, 512 MB–1 GB, mounted
`/boot/efi`) plus a root filesystem, swap if you want hibernation.

**User setup — this is the step that decides whether you get `sudo`:**

- **Leave the root password EMPTY.** The installer then installs `sudo` and puts
your user in the `sudo` group. That is the *only* thing that does this.
- **Set a root password instead** → you get root logins and **no `sudo`**. It is
  not a task: "standard system utilities" does *not* include it. (Verified in
tasksel 3.81 — the `standard` task is defined as `Packages: standard`, i.e. the
  `Priority: standard` set, and `sudo` is `Priority: optional`.) Adding it later
  is easy — see *First boot* — but the installer won't do it for you.

**Mirrors + components:** enable **`contrib`**, **`non-free`** and
**`non-free-firmware`**. The installer offers the last one for a reason: wifi and
GPU firmware live there.

**Software selection (tasksel):**

- **Uncheck the desktop environment.** This repo *is* the desktop.
- **Keep "standard system utilities".** Unticking it drops `man-db`, `locales`,
cron and friends — you'll spend the first ten minutes re-adding obvious things.

Then finish and reboot.

### 2. First boot (before the repo)

```sh
# Only if you set a root password at install time (i.e. you have no sudo).
# Log in as root, or `su -` from your user, then:
apt update && apt install sudo
usermod -aG sudo <you>          # ⚠️ takes effect on the NEXT login

# Stop apt from dragging in "recommends" everywhere. Debian's real bloat lives
# here (Arch has no equivalent — this is what makes apt behave like pacman).
printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' \
    | sudo tee /etc/apt/apt.conf.d/99no-recommends
```

⚠️ **`su` vs `su -`** (and the Arch reflex that breaks here): `usermod`,
`adduser`, `fdisk`, `visudo` and friends live in `/usr/sbin` and `/sbin`, which a
normal user's `PATH` does not include. A plain `su` makes you root but **keeps
your user's PATH**, so those come back as `command not found` even though the
binaries exist — and any command that "worked earlier" silently didn't. Use
**`su -`**, or `sudo`, or the full path. Arch hides this from you: usrmerge put
everything in `/usr/bin` and `/etc/profile` adds the sbin dirs for all users.

### 3. Then this repo

```sh
sudo apt install git stow                     # install.sh needs both
git clone git@github.com:Outsidetheklub/i3-dotfiles.git ~/i3-dotfiles
cd ~/i3-dotfiles
grep -v '^#' packages.debian.txt | xargs sudo apt install

./install.sh
sudo bash system-files/install-system.sh
# then the machine-specific files, exactly as in "Recreating this on another machine"
```

The X-side pieces — `xorg.conf.d`, LightDM, NetworkManager + iwd, Bluetooth, and
`localectl` for the keyboard — are identical on both distros.

### What Debian doesn't ship (and the fixes)

- **Package list:** `packages.debian.txt` (Arch names live in `packages.txt`).
  `install.sh` prints the right install command for whichever host it's run on.
- **polkit agent:** Debian has no `polkit-gnome`, so use **`mate-polkit`**. No
  config change needed — `startup.sh` calls `local-bin/.local/bin/polkit-agent`,
  which finds whatever agent the distro installed (Arch: polkit-gnome; Debian:
  mate-polkit / lxpolkit / polkit-kde-agent-1).
- **Nerd fonts, not Debian fonts:** the setup asks for the Nerd families
  (`Terminess Nerd Font Mono`, `FiraCode Nerd Font`). Debian's `fonts-terminus`
  and `fonts-firacode` are the *plain* fonts and do **not** provide them — install
  the nerd builds instead: <https://github.com/ryanoasis/nerd-fonts/releases> →
  `Terminus.zip` + `FiraCode.zip` →
  `unzip -o Terminus.zip FiraCode.zip -d ~/.local/share/fonts && fc-cache -f`.
- **`adw-gtk3`** (the GTK theme): not packaged — build it (meson/ninja, no
  compiler work) from <https://github.com/lassekongo83/adw-gtk3>.
- **`papirus-folders`** (the white folder recolour): not packaged — it's one bash
  script: <https://github.com/PapirusDevelopmentTeam/papirus-folders> →
  `/usr/local/bin` (`install.sh` uses it if present).
- **`uv`** (for `terminus-bold`): not in trixie —
  `curl -LsSf https://astral.sh/uv/install.sh | sh`.
- **Browser / Spotify:** `zen-browser` and `spotify-launcher` are Arch-only. On
  Debian: Zen's own apt repo / `.deb` / Flatpak (<https://zen-browser.app>), and
  Spotify's official apt repo (`spotify-client`) or Flatpak.
- **`local-bin/pkg-sources`** is Arch-only by design (it reads pacman/AUR data) —
  harmless on Debian, just useless.

### VM notes

- No vendor GPU driver: `mesa` (in the list) does software rendering, so skip the
  NVIDIA pieces. Output names differ too — a VM's X output is usually
  `Virtual-1`, so `local.conf` / `display.sh` need that instead of `DP-4`.
- Everything else — fonts, icons, cursor, i3, rofi, the scripts — behaves the
  same as on bare metal.

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

On the Latitude 7490 the output names are already solved — copy
`examples/display-laptop-7490.sh` (its known-good version).

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
grep -v '^#' packages.txt | xargs sudo pacman -S --needed   # + AUR: zen-browser-bin (see below)
# on Debian: `grep -v '^#' packages.debian.txt | xargs sudo apt install` — see "Debian (apt) machines"

# then deploy everything:
./install.sh
sudo bash system-files/install-system.sh
cp examples/local.conf ~/.config/i3/local.conf
cp examples/display.sh ~/.config/i3/display.sh
# ...or, on the Latitude 7490, its known-good version: examples/display-laptop-7490.sh
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

## Troubleshooting

Problems actually hit while installing this on real machines:

- **`pacman` fails with `<file> exists in filesystem`** (gschema / gtk / glib paths).
  Those files are on disk but owned by no package — the signature of an earlier
  pacman run that was interrupted (files extracted, database never updated). Every
  later pacman run then hits the same wall, which makes it look like the repo is
  broken. Cure:

  ```sh
  sudo rm -f /var/lib/pacman/db.lck
  grep -v '^#' packages.txt | xargs sudo pacman -S --overwrite='*'
  ```

  (`--overwrite='*'` only replaces files these packages ship themselves — it's the
  documented fix for this error, not a blanket force.)

- **`install.sh` says "GNU Stow is required"** — the packages aren't installed yet.
  Step 1 of [Install](#install) handles `git stow`; the rest is `packages.txt`.

- **`stow` aborts with "All operations aborted."** — a real file already exists
  where a symlink should go (usually a leftover from an older dotfiles repo). One
  conflict aborts the whole run. Check first with
  `stow -n -v --target="$HOME" <package>`, then `stow -D <package>` or move the
  offending file aside.

- **Greeter on the wrong monitor, or at 60 Hz instead of 240** — the greeter draws
  on the X server's *primary* output. `system-files/lightdm/50-i3.conf` documents
  both fixes (`active-monitor=`, or `display-setup-script` +
  `examples/lightdm-display-setup.sh`).

- **No sound in an ALSA-only app (e.g. DaVinci Resolve)** — `pipewire-alsa` is the
  ALSA→PipeWire bridge and is in `packages.txt`. (Resolve additionally can't decode
  AAC on Linux at all — licensing — so imports need FLAC/PCM audio.)

- **In a VM: X comes up black or not at all** — check the VM's video model (`qxl`
  or virtio-gpu; plain `std` VGA is a bad time) and that `mesa` is installed (it's
  in the list — virtio-vga needs it for GL / software rendering).

## Things worth knowing

- **Autostart is duplicate-guarded**: `redshift` is started with
  `pgrep -x <name> || <name>`, and `mouse-watch.sh` has a `flock` singleton, so
  `$mod+Shift+r` brings back anything that died without stacking up copies.
  No compositor is run at all (picom was dropped on 2026-09-28).
- **The bar is at the bottom** (`position bottom`), with a black/grey `colors`
  block because i3's stock blue for the focused workspace doesn't fit.
- **No Nerd Fonts are required** — the power menu uses plain words, so default
  `monospace` everywhere works.
- Wallpaper: none, solid black (`xsetroot`). Uncomment the `feh` line in
  `i3/.config/i3/startup.sh` if you want an image.
- Mouse accel has two layers on purpose: the driver-level `99-mouse-noaccel.conf`
  (permanent, all devices) plus the `mouse-watch.sh` watchdog, because Proton
  games reset the setting at runtime.
- **Gamepad vs blanking**: X11 only counts keyboard/mouse as activity, so the
  screen blanked mid-game whenever you played with a controller (the kernel saw
  the pad, X didn't). `src/gamepad-idle-guard.c` — built by `install.sh` into
  `~/.local/bin/` — watches `/dev/input` for gamepad events, disables DPMS while
  one is active, and restores blanking once you're demonstrably back on
  keyboard/mouse. Needs the user in the `input` group (see Prerequisites).
- **`<` `>` `|` on an ANSI keyboard**: the stock `se` layout puts them on `<LSGT>`,
  the key left of Z that ANSI boards don't have. `xkb/.config/xkb/symbols/seinans`
  adds them on the 3rd level, and `lv3:caps_switch` makes **Caps Lock** that 3rd
  level (`Caps + , . -` → `< > |`): Caps Lock has no other job on this machine, and
  right Alt works too.
  The variant is installed into **`/usr/share/X11/xkb`** by `install-system.sh`
  (X only resolves layouts from there — `~/.config/xkb` is for xkbcomp and
  libxkbcommon/Wayland), and set as the system default via `localectl`, so X applies
  it on **every** keyboard connect. That matters: a login-time script only runs once,
  and the keyboard (2.4G dongle / BT) re-enumerates into a new device after login —
  X then re-applies the default rules and would silently drop the mapping.
  `~/.xprofile` still applies it too, as a fallback for machines where the
  system-side step wasn't run (`setxkbmap -I` can't see `~/.config/xkb`, hence the
  `... -print | xkbcomp -I"$HOME/.config/xkb" - "$DISPLAY"` pipeline).
