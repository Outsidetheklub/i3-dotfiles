#!/bin/sh
# Per-machine LightDM greeter display setup — NOT tracked, copy + edit if needed.
#
# LightDM runs this before the greeter appears (display-setup-script in
# system-files/lightdm/50-i3.conf). Needed when the greeter lands on the wrong
# monitor or at the wrong refresh rate.
#
# Install:
#   sudo install -Dm755 examples/lightdm-display-setup.sh \
#        /usr/local/bin/lightdm-display-setup.sh
#   then uncomment display-setup-script=... in system-files/lightdm/50-i3.conf
#
# Find output names:   xrandr --query | grep ' connected'
# Find refresh rates:  xrandr --query          (* = current, + = preferred)
#
# Delete this file's contents (or don't install it) on a machine whose greeter
# already lands where it should — a missing script would make LightDM complain.

# Desktop, Debian-era output names (2026-10-31): DP-2 = AOC 27G2ZNE, main +
# primary at 1920x1080@240; HDMI-0 = secondary on the right.
# ⚠️ Output names follow the driver, not the monitor: this box said DP-4 on Arch
# and DP-2 on Debian. Re-check before reuse:  xrandr --query | grep ' connected'
# Without this the greeter sits on HDMI-0 (the first enabled output X reports).
/usr/bin/xrandr --output DP-2 --mode 1920x1080 --rate 240 --primary --pos 0x0 2>/dev/null \
    || /usr/bin/xrandr --output DP-2 --primary 2>/dev/null || true
/usr/bin/xrandr --output HDMI-0 --mode 1920x1080 --rate 60 --pos 1920x0 2>/dev/null || true
