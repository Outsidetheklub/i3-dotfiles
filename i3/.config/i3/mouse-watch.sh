#!/bin/sh
# Watchdog: keeps mouse acceleration off (libinput "flat" profile).
# Proton games love to reset these — so re-apply every 5 seconds.
#
# Why this exists at all: the permanent driver-level fix is
# /etc/X11/xorg.conf.d/99-mouse-noaccel.conf. This is the belt-and-braces
# for games that flip the setting at runtime.
#
# Two fixes over the old version:
#   1. Singleton (flock) — i3 starts this with exec_always, so restarting i3
#      must not stack up copies of an infinite loop.
#   2. Device-agnostic — old version hardcoded device id 12, which breaks the
#      moment a peripheral is plugged/unplugged and the ids shift. Now it hits
#      every device that exposes the libinput accel properties.

# Useless outside an X session (e.g. a leftover process after logout)
[ -n "$DISPLAY" ] || exit 0

# Singleton per X display
lock="/tmp/.mouse-watch-$(printf '%s' "$DISPLAY" | tr -d ':/').lock"
exec 9>"$lock"
flock -n 9 || exit 0

while true; do
    xinput list --short 2>/dev/null \
        | sed -n 's/.*id=\([0-9]*\).*/\1/p' \
        | while read -r id; do
            xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null
            xinput set-prop "$id" "libinput Accel Profile Enabled" 0, 1, 0 2>/dev/null
        done
    sleep 5
done
