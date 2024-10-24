{
  config,
  modulesPath,
  lib,
  pkgs,
  ...
}:
let
  cirrusToken = builtins.getEnv "CIRRUS_WORKER_TOKEN";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  options.worker = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "worker name";
      example = "ax52";
    };
    cpu = lib.mkOption {
      type = lib.types.str;
      description = "How much CPU the worker has (use half core count for shared vCPUs)";
      example = "1";
    };
    ram = lib.mkOption {
      type = lib.types.str;
      description = "Total ram available (MB) to the worker";
      example = "2000";
    };
  };

  config = {
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
        # willcl-ark
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH988C5DbEPHfoCphoW23MWq9M6fmA4UTXREiZU0J7n0 will.hetzner@temp.com"
      ];

    systemd.services.cirrus-worker = {
      description = "Cirrus CI Worker";
      after = [ "network.target" "docker.service" ];
      wants = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = "/run/current-system/sw/bin/test -f /etc/cirrus/worker.yaml";
        ExecStart = "${pkgs.cirrus-cli}/bin/cirrus worker run --file /etc/cirrus/worker.yaml";
        Restart = "always";
        RestartSec="10";
        User = "cirrus-worker";
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
        RESTART_CI_DOCKER_BEFORE_RUN = "1";
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
    # Generate the Cirrus worker config file
    system.activationScripts = {
      cirrusWorkerConfig = ''
        mkdir -p /etc/cirrus
        cat > /etc/cirrus/worker.yaml << EOF
token: ${cirrusToken}

name: "${config.worker.name}"

labels:
  type: ${config.worker.name}
  cpu: "${config.worker.cpu}"
  ram: "${config.worker.ram}"

resources:
  cpu: ${config.worker.cpu}
  memory: ${config.worker.ram}
EOF

        chown -R cirrus-worker:cirrus-worker /etc/cirrus
        chmod 600 /etc/cirrus/worker.yaml
      '';

      cirrusWorkerDir = ''
        mkdir -p /var/lib/cirrus-worker/.cache
        chown cirrus-worker:cirrus-worker /var/lib/cirrus-worker/.cache
        chmod 700 /var/lib/cirrus-worker/.cache
      '';
    };

    system.stateVersion = "24.05";

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
  };
}
