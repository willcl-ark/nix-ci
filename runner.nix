{
  config,
  modulesPath,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;
  virtualisation.podman.enable = true;

  # Configure docker in rootless mode to run the CI scripts
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
    daemon.settings = {
      data-root = "/docker/data-root";
    };
  };

  environment.systemPackages = map lib.lowPrio [
    pkgs.ccache
    pkgs.cirrus-cli
    pkgs.curl
    pkgs.gitMinimal
    pkgs.nebula
  ];

  # Use authorized keys supplied at runtime from the deployment command
  users.users.root.openssh.authorizedKeys.keys =
    let
      sshKey = builtins.getEnv "CI_WORKER_SSH_KEY";
    in
    if sshKey != ""
    then [ sshKey ]
    else [
      # b10c
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtQmhXAp3F/KcaK3NzA30b2jE26zdYg6msXTXMBVJvZ8p8adHVYrl1QVFieeIjZvy1sj0gMXPOjYpgOm7OdwiZL4h0B9/FU49h+TLly6+YBwO/XYDR84WCvtv1/HVrVSIcYdMZo2+5fnGV3zxrtC/ndBheu17PbW7pvB+O7ODjxJa2tu66Q0If1cYH85PNkF3/jzsjQRwzo88eMxPEqVfp3MfYxJR53oWlXN2SUe1F/6FkeUulx9FpHgmWtPVLsGLd285GeQwsBUIRl+VnJQwCSB69YWgATR0zlRloFcfu1DhOCo5rGXnOvGmOWZ9LYpybwvuotQ8AGbsdNpZWYhQUNGF/YealVkyKABKhIHRQcGkqqqSGHpx6ui1tLkBHJWFgdCTU6eaK9OhgnjyHDJDtPGDl/Ek84JGYHp8+seHvE0/4GvQ2hQXUEUSQpxNwlwT1TKJ8uEMQuSn5zOK9TBSrYktW9h7HRe0ZQd23C6J38Lhxt9bJ3FcyfxFqogJZz3szAo0iR/bsjyeErfjKqeDHDZu4x9OISntrL42tCtNnb9ucWHo2nd+y+2X/hGQlGDdCo+RFi4cZeIHusibmr6J8FHnYgtNldamU2MYKk9R26MmPwVD/eM1Eq/sKL1jhAH3vfnxSifsQ6DvMicRiXWy/AOb3ZdZWVCLSd0mmrjkncQ=="
    ];


  # The cirrus worker requires a token to connect.
  # Currently this requires manual positioning in /etc/cirrus/worker.env in the form:
  # CIRRUS_TOKEN=<token>
  systemd.services.cirrus-worker = {
    description = "Cirrus CI Worker";
    after = [ "network.target" "docker.service" ];
    wants = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.cirrus-cli}/bin/cirrus worker run --token $CIRRUS_TOKEN --labels type=ax52_x86-64";
      Restart = "always";
      User = "cirrus-worker";
      EnvironmentFile = "/etc/cirrus/worker.env";
    };
    environment = {
      XDG_CACHE_HOME = "/var/lib/cirrus-worker/.cache";
      PATH = lib.mkForce (lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.systemd
        pkgs.cirrus-cli
        pkgs.docker
        pkgs.python3
      ]);
      DOCKER_HOST = "unix:///var/run/docker.sock";
    };
  };

  users.users.cirrus-worker = {
    isSystemUser = true;
    group = "cirrus-worker";
    description = "Cirrus CI worker user";
    home = "/var/lib/cirrus-worker";
    createHome = true;
    shell = pkgs.bash;
    extraGroups = [ "docker" ];
  };
  users.groups.cirrus-worker = {};

  # Create /etc/cirrus directory and /var/lib/cirrus-worker/.cache
  system.activationScripts = {
    cirrusWorkerDir = ''
      mkdir -p /etc/cirrus
      chmod 755 /etc/cirrus
      mkdir -p /var/lib/cirrus-worker/.cache
      chown cirrus-worker:cirrus-worker /var/lib/cirrus-worker/.cache
      chmod 700 /var/lib/cirrus-worker/.cache
    '';
  };

  system.stateVersion = "24.05";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };
}
