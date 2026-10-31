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

# ── Example A: two monitors + NVIDIA vsync (the desktop's version) ──────────
# Output names follow the driver, not the monitor: the same panel was DP-4 on
# Arch and DP-2 on Debian. Re-check instead of copying names.
# The nvidia-settings call turns on the composition pipeline, which is what stops
# tearing when no compositor is running (picom stays off on this box). Learned the
# hard way on 2026-10-31:
#   * Keep ViewPortIn/ViewPortOut in every head's braces. A metamode that lists
#     only {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}
#     re-initialises the head and the panel can lose signal (dark screen).
#   * Don't follow it with an `xrandr --output <secondary>` mode set: the head
#     gets its mode twice within a second and can drop out. Use xrandr for the
#     primary flag only, and recover with `display-recover` if it ever blanks.
#   * Two heads with the pipeline have been stable once the two rules above hold.
#
# if xrandr --query | grep -q '^DP-2 connected'; then
#     nvidia-settings -a "CurrentMetaMode=DPY-3: 1920x1080_240 @1920x1080 +0+0 {ViewPortIn=1920x1080, ViewPortOut=1920x1080+0+0, ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, DPY-0: nvidia-auto-select @1920x1080 +1920+0 {ViewPortIn=1920x1080, ViewPortOut=1920x1080+0+0, ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}" >/dev/null 2>&1 || true
#     xrandr --output DP-2 --primary 2>/dev/null || true
# fi

# ── Example B: second monitor to the right of the main one (no NVIDIA) ──────
# if xrandr --query | grep -q '^HDMI-0 connected'; then
#     xrandr --output HDMI-0 --mode 1920x1080 --rate 60.00 --right-of DP-2 2>/dev/null \
#         || xrandr --output HDMI-0 --auto --right-of DP-2 2>/dev/null
# fi

# Nothing to do on a single-screen machine.
