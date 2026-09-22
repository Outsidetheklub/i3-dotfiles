#!/bin/sh
# Machine-specific display setup — NOT tracked in the repo.
# Copy to ~/.config/i3/display.sh, make it executable, and edit.
# startup.sh runs it if it exists.
#
# Find output names:  xrandr --query | grep ' connected'
# See modes:          xrandr --query
#
# Why this file exists: i3 (and X itself) never enable extra outputs. Without an
# xrandr call here, a second monitor stays black no matter what the i3 config says.

# ── Example: second monitor to the right of the main one ────────────────────
# if xrandr --query | grep -q '^HDMI-0 connected'; then
#     xrandr --output HDMI-0 --mode 1920x1080 --rate 60.00 --right-of DP-4 2>/dev/null \
#         || xrandr --output HDMI-0 --auto --right-of DP-4 2>/dev/null
# fi

# Nothing to do on a single-screen machine.
