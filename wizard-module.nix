{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.services.openclaw-wizard;
  openclawCfg = config.services.openclaw;
  wizardSrc = ./wizard;
in
{
  options.services.openclaw-wizard = {
    enable = lib.mkEnableOption "OpenClaw settings web UI";

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address the wizard web server binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port the wizard web server listens on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for the wizard port.";
    };

    configPath = lib.mkOption {
      type = lib.types.str;
      default = "${openclawCfg.dataDir}/user-config.json";
      description = "Path to the user-config.json the wizard will edit.";
    };

    ppqCreditPath = lib.mkOption {
      type = lib.types.str;
      default = "${openclawCfg.dataDir}/ppq-credit.json";
      description = "Path to the ppq-credit.json file for PPQ account credentials.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure the openclaw user can restart the service
    security.sudo.extraRules = [{
      users = [ openclawCfg.user ];
      commands = [{
        command = "/run/current-system/sw/bin/systemctl restart openclaw.service";
        options = [ "NOPASSWD" ];
      }];
    }];

    systemd.services.openclaw-wizard = {
      description = "OpenClaw Settings Web UI";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = openclawCfg.user;
        Group = openclawCfg.group;
        ExecStart = "${pkgs.python3}/bin/python3 ${wizardSrc}/server.py";
        WorkingDirectory = toString wizardSrc;
        Restart = "on-failure";
        RestartSec = 5;

        Environment = [
          "HOME=${openclawCfg.dataDir}"
          "WIZARD_HOST=${cfg.host}"
          "WIZARD_PORT=${toString cfg.port}"
          "WIZARD_CONFIG_PATH=${cfg.configPath}"
          "WIZARD_PPQ_CREDIT_PATH=${cfg.ppqCreditPath}"
        ];
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
