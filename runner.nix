{
  config,
  modulesPath,
  lib,
  pkgs,
  name,
  arch,
  type,
  ...
}:
let
  CIRRUS_WORKER_HOME = "/var/lib/cirrus-worker";
  secretsFile = ./sops/${name}.yaml;
  secretsProvisioned = builtins.pathExists secretsFile;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  assertions = [
    {
      assertion = !(type == "arm64" && arch != "aarch64-linux");
      message = "can't use a type=${type} on a ${arch} host";
    }
  ];

  networking.hostName = name;

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

  sops = {
    # during installation, we don't have the secrets yet. Don't fail
    # the deployment, but warn the user on all deployments.
    defaultSopsFile = if secretsProvisioned then secretsFile else null;
    secrets = if secretsProvisioned then {
      "cirrus.env" = {
        mode = "0400";
        owner = config.users.users.cirrus-worker.name;
        group = config.users.groups.cirrus-worker.name;
        path = "${CIRRUS_WORKER_HOME}/cirrus.env";
        restartUnits = [ "cirrus-worker.service" ];
      };
    } else lib.warn "\n\n\t\t Secrets aren't provisioned - without secrets, the CI runner will not work.\n\n" {};
  };

  environment.systemPackages = with pkgs; map lib.lowPrio [
    ccache
    curl
    gitMinimal
    htop
  ];

  # Use authorized keys supplied at runtime from the deployment command
  users.users.root.openssh.authorizedKeys.keys =
    let
      sshKey = builtins.getEnv "CI_WORKER_SSH_KEY";
    in
    if sshKey != "" then
      [ sshKey ]
    else
      [
        # b10c
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtQmhXAp3F/KcaK3NzA30b2jE26zdYg6msXTXMBVJvZ8p8adHVYrl1QVFieeIjZvy1sj0gMXPOjYpgOm7OdwiZL4h0B9/FU49h+TLly6+YBwO/XYDR84WCvtv1/HVrVSIcYdMZo2+5fnGV3zxrtC/ndBheu17PbW7pvB+O7ODjxJa2tu66Q0If1cYH85PNkF3/jzsjQRwzo88eMxPEqVfp3MfYxJR53oWlXN2SUe1F/6FkeUulx9FpHgmWtPVLsGLd285GeQwsBUIRl+VnJQwCSB69YWgATR0zlRloFcfu1DhOCo5rGXnOvGmOWZ9LYpybwvuotQ8AGbsdNpZWYhQUNGF/YealVkyKABKhIHRQcGkqqqSGHpx6ui1tLkBHJWFgdCTU6eaK9OhgnjyHDJDtPGDl/Ek84JGYHp8+seHvE0/4GvQ2hQXUEUSQpxNwlwT1TKJ8uEMQuSn5zOK9TBSrYktW9h7HRe0ZQd23C6J38Lhxt9bJ3FcyfxFqogJZz3szAo0iR/bsjyeErfjKqeDHDZu4x9OISntrL42tCtNnb9ucWHo2nd+y+2X/hGQlGDdCo+RFi4cZeIHusibmr6J8FHnYgtNldamU2MYKk9R26MmPwVD/eM1Eq/sKL1jhAH3vfnxSifsQ6DvMicRiXWy/AOb3ZdZWVCLSd0mmrjkncQ=="
        # willcl-ark
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH988C5DbEPHfoCphoW23MWq9M6fmA4UTXREiZU0J7n0 will.hetzner@temp.com"
      ];

  systemd.services.cirrus-worker = {
    description = "Cirrus CI Worker";
    after = [
      "network.target"
      "docker.service"
    ];
    wants = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.cirrus-cli}/bin/cirrus worker run --name ${name} --token $CIRRUS_TOKEN --labels type=${type}";
      Restart = "always";
      User = config.users.users.cirrus-worker.name;
      EnvironmentFile = "${CIRRUS_WORKER_HOME}/cirrus.env";
    };
    environment = {
      XDG_CACHE_HOME = "${CIRRUS_WORKER_HOME}/.cache";
      PATH = lib.mkForce (
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.gnused
          pkgs.systemd
          pkgs.cirrus-cli
          pkgs.docker
          pkgs.python3
          pkgs.git
        ]
      );
      DOCKER_HOST = "unix:///var/run/docker.sock";
      RESTART_CI_DOCKER_BEFORE_RUN = "1";
    };
  };

  users.users.cirrus-worker = {
    isSystemUser = true;
    group = "cirrus-worker";
    description = "Cirrus CI worker user";
    home = CIRRUS_WORKER_HOME;
    createHome = true;
    shell = pkgs.bash;
    extraGroups = [ "docker" ];
  };
  users.groups.cirrus-worker = { };

  # Create CIRRUS_WORKER_HOME/.cache
  system.activationScripts = {
    cirrusWorkerDir = ''
      mkdir -p ${CIRRUS_WORKER_HOME}/.cache
      chown cirrus-worker:cirrus-worker ${CIRRUS_WORKER_HOME}/.cache
      chmod 700 ${CIRRUS_WORKER_HOME}/.cache
    '';
  };

  system.stateVersion = "24.05";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
