# i3-dotfiles

My X11/i3 desktop setup. Deliberately minimal and **un-themed**: plain black,
default fonts, no effects. It's the stable fallback I keep around for when
Wayland/niri misbehaves, so it's built for things that must not break —
monitors, mouse acceleration, keybinds — not for looks.

## What's in here

| Path | Goes to | What it does |
|---|---|---|
| `i3/.config/i3/config` | `~/.config/i3/` | the whole WM config — keybinds, workspace→monitor mapping, autostart |
| `i3/.config/i3/startup.sh` | `~/.config/i3/` | displays (xrandr), polkit agent, flameshot, gamepad idle guard |
| `i3/.config/i3/mouse-watch.sh` | `~/.config/i3/` | watchdog that keeps libinput mouse acceleration off (games reset it) |
| `i3status/.config/i3status/config` | `~/.config/i3status/` | bar modules: wifi, disk free, RAM used/available, clock |
| `rofi/.config/rofi/config.rasi` | `~/.config/rofi/` | launcher — black, centered, no icons. Also used by the power menu |
| `dunst/.config/dunst/dunstrc` | `~/.config/dunst/` | notifications — flat black |
| `picom/.config/picom/picom.conf` | `~/.config/picom/` | compositing + vsync only, no shadows/fading/transparency |
| `kitty/.config/kitty/kitty.conf` | `~/.config/kitty/` | terminal — default colours on purpose, CSD title bar hidden |
| `local-bin/.local/bin/power-menu.sh` | `~/.local/bin/` | rofi power menu ($mod+Escape) |
| `xprofile/.xprofile` | `~/.xprofile` | repaints the root window black (kills the ghost SDDM screen) |
| `system-files/99-mouse-noaccel.conf` | `/etc/X11/xorg.conf.d/` | the actual fix for mouse acceleration (needs root, see below) |

## Install

```sh
git clone https://github.com/outsidetheklub/i3-dotfiles.git ~/i3-dotfiles
cd ~/i3-dotfiles
./install.sh
```

`install.sh` symlinks everything with GNU Stow (`stow --restow --target=$HOME`).
It refuses to clobber real files — if you already have e.g. `~/.config/i3/config`
as a real file, move it out of the way first.

Packages: see `packages.txt`.

The mouse-accel file is **the only root-owned part** and is not stowed:

```sh
sudo cp system-files/99-mouse-noaccel.conf /etc/X11/xorg.conf.d/
```

## Keybinds

`$mod` = Super.

| Keys | Action |
|---|---|
| `$mod+Return` / `$mod+b` | kitty / browser |
| `$mod+e` / `$mod+p` | Thunar / pavucontrol |
| `$mod+space` / `$mod+Escape` | rofi launcher / rofi power menu |
| `$mod+h/j/k/l` | focus (arrows too) |
| `$mod+Shift+h/j/k/l` | move window |
| `$mod+1..0` | workspace 1–10 (`$mod+Shift+1..0` moves container) |
| `$mod+f`, `$mod+q`, `$mod+Shift+space` | fullscreen, kill, floating |
| `$mod+r` | resize mode (h/j/k/l, Enter/Esc to exit) |
| `$mod+Shift+c` / `$mod+Shift+r` | reload / restart i3 |
| `$mod+m` | Spotify |
| Print / `$mod+Shift+s` | flameshot full / region |

## Things worth knowing

- **Monitors are hardcoded**: `DP-4` (main) and `HDMI-0` (secondary, right of it).
  Workspaces 1–5 live on DP-4, 6–10 on HDMI-0. Change the names in
  `i3/.config/i3/config` and `startup.sh` on a different machine
  (`xrandr --query` to find them).
- **i3 does not enable outputs by itself** — without the `xrandr` line in
  `startup.sh`, the second monitor stays black.
- **Autostart is duplicate-guarded**: `picom`/`redshift`/`dunst` are started with
  `pgrep -x <name> || <name>`, and `mouse-watch.sh` has a `flock` singleton, so
  `$mod+Shift+r` brings back anything that died without stacking up copies.
- **The bar is at the bottom** (`position bottom`), with a black/grey `colors`
  block because i3's stock blue for the focused workspace doesn't fit.
- **No Nerd Fonts are required** — the power menu uses plain words, so default
  `monospace` everywhere works.
- Wallpaper: none, solid black (`xsetroot`). Uncomment the `feh` line in
  `startup.sh` if you want an image.
