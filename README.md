# Example Nix deployment for Bitcoin Core CI

## host setup

- Add a new runner in the flake.nix (e.g. copy runner01)
- With nixos-anywhere (e.g. `nix-shell -p nixos-anywhere`), run `nixos-anywhere --flake .#runnerXX root@<ip address>`



## deployment command

```bash
NIX_SSHOPTS="-i /home/will/.ssh/hetzner-temp" nixos-rebuild switch --flake .#hetzner-cloud --target-host root@188.245.174.208 --show-trace
```
