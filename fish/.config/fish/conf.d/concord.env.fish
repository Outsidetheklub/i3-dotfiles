# Rust/cargo shell integration. `rustup` writes ~/.cargo/env.fish — but a
# machine without Rust (the laptop) has no such file, and a bare `source`
# errors on EVERY shell start ("No such file or directory: ~/.cargo/env.fish"),
# i.e. every kitty window. Guard it, like uv.env.fish does.
test -f "$HOME/.cargo/env.fish" && source "$HOME/.cargo/env.fish"
