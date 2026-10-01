# `nx <package> [args...]` — run a program straight from nixpkgs, without
# installing it (it lands in /nix/store and is reused from there afterwards).
#
#   nx btop                     ->  nix run nixpkgs#btop --
#   nx hyperfine -w 3 'cmd'     ->  nix run nixpkgs#hyperfine -- -w 3 'cmd'
#   nx ncdu /home               ->  nix run nixpkgs#ncdu -- /home
#
# $argv[1] is the package; everything after it goes to the program untouched.
# The `--` matters: without it nix would eat flags like --version or -p.
# Prune what you've collected with `nix-collect-garbage -d`.
function nx --description 'run a nixpkgs program without installing it'
    if test (count $argv) -eq 0
        echo "usage: nx <package> [args...]    e.g. nx btop" >&2
        return 2
    end
    nix run "nixpkgs#$argv[1]" -- $argv[2..-1]
end
