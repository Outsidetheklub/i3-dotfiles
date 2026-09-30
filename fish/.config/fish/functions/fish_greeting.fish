function fish_greeting
    fastfetch
end

# No --key-padding-left: it indented every key by 5 columns but not the title line
# above them, so the two never lined up. That padding exists to make room for an
# ASCII logo on the left; the logo is back now (2026-09-30 — see
# ~/i3-dotfiles/fastfetch/.config/fastfetch/config.jsonc), but the keys are lined
# up by that config's fixed 12-char key column instead, so the padding stays off.
