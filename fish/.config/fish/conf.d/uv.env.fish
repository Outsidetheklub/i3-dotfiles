# Tool scripts live in ~/.local/bin (mono-cursor, screenshot.sh, power-menu.sh,
# network-rofi.sh, pkg-sources, …), so it needs to be on PATH.
fish_add_path -g "$HOME/.local/bin"

# uv's shell integration. `uv tool update-shell` writes ~/.local/bin/env.fish and
# points this file at it — but that file only exists once uv has run on this
# machine, and a missing `source` errors on EVERY shell start. Guard it.
test -f "$HOME/.local/bin/env.fish" && source "$HOME/.local/bin/env.fish"
