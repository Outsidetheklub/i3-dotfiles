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

# Desktop, 2026-09-26: DP-4 = AOC 27G2ZNE, main + primary, 1920x1080@240.
# Without this the greeter sits on HDMI-0 (the primary output X picks by default).
/usr/bin/xrandr --output DP-4 --mode 1920x1080 --rate 240 --primary 2>/dev/null \
    || /usr/bin/xrandr --output DP-4 --primary 2>/dev/null || true
