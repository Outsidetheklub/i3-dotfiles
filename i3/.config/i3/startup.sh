#!/bin/sh
# i3 startup — 2026-09-22 (rebuilt from zero, trimmed to the essentials)
# Wallpaper + polkit + flameshot + gamepad guard.
# Mouse accel is handled system-wide (/etc/X11/xorg.conf.d/99-mouse-noaccel.conf
# + mouse-watch.sh). Quickshell was removed from the i3 setup on 2026-09-22.

# Wait for X to settle
sleep 1

# Monitors: DP-4 (main, primary) + HDMI-0 (secondary, to the right, 1920x1080@60).
# Workspaces 1-5 live on DP-4, 6-10 on HDMI-0 (see the i3 config).
# i3 does NOT enable outputs on its own — without this HDMI-0 stays black.
if xrandr --query 2>/dev/null | grep -q '^HDMI-0 connected'; then
    xrandr --output HDMI-0 --mode 1920x1080 --rate 60.00 --right-of DP-4 2>/dev/null \
        || xrandr --output HDMI-0 --auto --right-of DP-4 2>/dev/null
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

# Flameshot — the xdg portal isn't ready at boot, so it exits immediately;
# skip if already running, otherwise retry until it sticks.
(
    pgrep -x flameshot >/dev/null 2>&1 && exit 0
    for i in 1 2 3 4 5 6; do
        flameshot >/dev/null 2>&1 &
        sleep 3
        pgrep -x flameshot >/dev/null 2>&1 && break
    done
) &

# Gamepad idle guard — DPMS can't see controller input, so it would blank the
# screen mid-game ("AFK"). Disables blanking while the gamepad is in use and
# restores it afterwards. (singleton via flock)
~/.local/bin/gamepad-idle-guard >> /tmp/gamepad-idle-guard.log 2>&1 &
