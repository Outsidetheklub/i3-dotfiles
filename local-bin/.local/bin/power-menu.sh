#!/bin/sh
# rofi power menu — bound to $mod+Escape in the i3 config.
# Plain-text labels (2026-09-22): the old ones used Nerd Font glyphs, which
# render as boxes now that the setup deliberately uses default fonts.
# ⚠️ Lock needs i3lock (installed).

# printf, not echo -e: this runs under /bin/sh (dash), whose echo treats -e as
# literal text — the first entry rendered as "-e Shutdown" and never matched.
chosen=$(printf '%s\n' Shutdown Reboot Logout Lock Sleep | rofi -dmenu -p "Power" -lines 5)
case "$chosen" in
    "Shutdown") systemctl poweroff ;;
    "Reboot")   systemctl reboot ;;
    "Logout")   i3-msg exit ;;
    "Lock")     i3lock 2>/dev/null || loginctl lock-session ;;
    "Sleep")    systemctl suspend ;;
esac
