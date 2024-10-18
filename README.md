# Example Nix deployment for Bitcoin Core CI

## deployment command

```bash
NIX_SSHOPTS="-i /home/will/.ssh/hetzner-temp" nixos-rebuild switch --flake .#hetzner-cloud --target-host root@188.245.174.208 --show-trace
```
