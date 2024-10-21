nixos-rebuild switch \
  --fast \
  --flake .#$1 \
  --target-host $1 \
  --build-host $1 \
  --use-remote-sudo
