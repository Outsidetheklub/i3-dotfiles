#!/bin/sh
# autorandr_hotplug.sh — called by udev when a DRM connector changes
# (monitor/projector plugged in or unplugged).
#
# 1. Applies the matching autorandr profile for the logged-in user's active X
#    session (laptop <-> hdmi).
# 2. Falls back to display.sh when NO profile matches. autorandr matches on the
#    monitor's EDID/serial, not just the connector name, so an unknown projector
#    (school, meeting room) matches nothing and would otherwise stay black.
#    display.sh enables the first connected external at its preferred mode.
#
# DISPLAY/XAUTHORITY are read from the user's i3 process because the display
# manager generates a fresh Xauthority file on every login (/tmp/xauth_*), so
# the values must be discovered at runtime, never hardcoded.
#
# Installed at /usr/local/bin/autorandr_hotplug.sh — source lives in
# i3-dotfiles/system-files/. Loaded by /etc/udev/rules.d/95-monitor-hotplug.rules.

sleep 1

USERNAME="vasileioslap"
USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
I3_PID=$(pgrep -u "$USERNAME" -x i3 | head -n 1)
[ -z "$I3_PID" ] && exit 0

ENVFILE="/proc/$I3_PID/environ"
DISPLAY_VAL=$(tr '\0' '\n' < "$ENVFILE" | sed -n 's/^DISPLAY=//p' | head -n 1)
XAUTH_VAL=$(tr '\0' '\n' < "$ENVFILE" | sed -n 's/^XAUTHORITY=//p' | head -n 1)
[ -z "$DISPLAY_VAL" ] && exit 0

SETENV="DISPLAY=$DISPLAY_VAL"
[ -n "$XAUTH_VAL" ] && SETENV="$SETENV XAUTHORITY=$XAUTH_VAL"

as_user() {
    runuser -u "$USERNAME" -- env $SETENV "$@"
}

# 1. Preferred: let autorandr switch profiles.
as_user autorandr --change

# 2. Fallback: an external output that is connected but still disabled means no
#    profile matched. Enable it with its own preferred mode via display.sh.
#    (xrandr shows a connected-but-off output as: HDMI-1 connected (normal ...))
if as_user xrandr --query 2>/dev/null | awk '/^(HDMI|DP)-[0-9]+ connected/ && $3 ~ /^\(/ {found=1} END {exit !found}'; then
    [ -x "$USER_HOME/.config/i3/display.sh" ] && as_user "$USER_HOME/.config/i3/display.sh"
fi

exit 0
