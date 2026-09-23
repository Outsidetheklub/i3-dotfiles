#!/bin/sh
# rofi power menu — bound to $mod+Escape in the i3 config.
# Plain-text labels (2026-09-22): the old ones used Nerd Font glyphs, which
# render as boxes now that the setup deliberately uses default fonts.
# ⚠️ Lock needs i3lock (installed).

entries="Shutdown\nReboot\nLogout\nLock\nSleep"
chosen=$(echo -e "$entries" | rofi -dmenu -p "Power" -lines 5)
case "$chosen" in
    "Shutdown") systemctl poweroff ;;
    "Reboot")   systemctl reboot ;;
    "Logout")   i3-msg exit ;;
    "Lock")     i3lock 2>/dev/null || loginctl lock-session ;;
    "Sleep")    systemctl suspend ;;
esac
