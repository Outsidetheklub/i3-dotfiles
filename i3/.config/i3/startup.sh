#!/bin/sh
# i3 startup — 2026-09-22 (rebuilt from zero, trimmed to the essentials)
# Wallpaper + polkit + gamepad guard.
# Mouse accel is handled system-wide (/etc/X11/xorg.conf.d/99-mouse-noaccel.conf
# + mouse-watch.sh). Quickshell was removed from the i3 setup on 2026-09-22.

# Wait for X to settle
sleep 1

# Machine-specific values (untracked, optional): see examples/machine.env.
# Sourced before anything below, so display.sh and the scripts can use it.
[ -f "$HOME/.config/i3/machine.env" ] && . "$HOME/.config/i3/machine.env"

# Machine-specific display setup lives OUTSIDE this repo (so the same files work
# on every machine): ~/.config/i3/display.sh — copy examples/display.sh and edit.
# It's optional: nothing happens if the file isn't there.
#
# i3 does NOT enable outputs by itself, so on a multi-monitor machine this file
# is what turns the second screen on.
if [ -x "$HOME/.config/i3/display.sh" ]; then
    "$HOME/.config/i3/display.sh"
fi

# Night light — only when this machine has a location configured. Unset means we
# simply don't start redshift (no wrong-location tint for anyone else's clone).
if [ -n "${REDSHIFT_LOCATION:-}" ]; then
    pgrep -x redshift >/dev/null 2>&1 || redshift -l "$REDSHIFT_LOCATION" &
fi

# Background: none — solid black. i3/X have no wallpaper of their own; the root
# window is black unless something paints it. To go back to an image later,
# uncomment the feh line (image must exist) —
# feh --bg-fill "$HOME/Pictures/Wallpapers/52HVcjStCQTsaDJWzEt946.jpg"
xsetroot -solid "#000000"

# Polkit auth agent (so Thunar can ask for a password to mount drives etc).
# Guarded so restarting i3 doesn't stack up agents.
pgrep -f "[p]olkit-gnome-authentication-agent-1" >/dev/null 2>&1 || \
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# Screenshots need no daemon any more: maim + slop + xclip, via
# ~/.local/bin/screenshot.sh (bound to Print / $mod+Shift+s in the i3 config).
# flameshot's login-time retry loop is gone with it — see 2026-09-26.

# Gamepad idle guard — DPMS can't see controller input, so it would blank the
# screen mid-game ("AFK"). Disables blanking while the gamepad is in use and
# restores it afterwards. (singleton via flock)
~/.local/bin/gamepad-idle-guard >> /tmp/gamepad-idle-guard.log 2>&1 &
