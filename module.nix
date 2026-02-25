# NixOS module for OpenClaw
#
# Philosophy: Build JSON config from Nix options using submodules.
# Option definitions are split into options/*.nix files.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.openclaw;

  # Helper to filter null values from profile attrs
  filterProfile = profile: lib.filterAttrs (n: v: v != null) profile;

  # Build configuration JSON from module options
  openclawConfig = {
    gateway = {
      port = cfg.gateway.port;
      mode = cfg.gateway.mode;
      bind = cfg.gateway.bind;
      auth = {
        mode = cfg.gateway.auth.mode;
      } // lib.optionalAttrs (cfg.gateway.auth.token != null) {
        token = cfg.gateway.auth.token;
      } // lib.optionalAttrs (cfg.gateway.auth.password != null) {
        password = cfg.gateway.auth.password;
      };
      tailscale = {
        mode = cfg.gateway.tailscale.mode;
        resetOnExit = cfg.gateway.tailscale.resetOnExit;
      };
    };

    browser = {
      executablePath = cfg.browser.executablePath;
      headless = cfg.browser.headless;
      noSandbox = cfg.browser.noSandbox;
      defaultProfile = cfg.browser.defaultProfile;
    } // lib.optionalAttrs (!cfg.browser.enabled) {
      enabled = false;
    } // lib.optionalAttrs cfg.browser.attachOnly {
      attachOnly = true;
    } // lib.optionalAttrs (cfg.browser.color != null) {
      color = cfg.browser.color;
    } // lib.optionalAttrs (cfg.browser.profiles != { }) {
      profiles = lib.mapAttrs (name: profile: filterProfile profile) cfg.browser.profiles;
    };

    logging = {
      level = cfg.logging.level;
      consoleLevel = cfg.logging.consoleLevel;
      consoleStyle = cfg.logging.consoleStyle;
      redactSensitive = cfg.logging.redactSensitive;
      redactPatterns = cfg.logging.redactPatterns;
    } // lib.optionalAttrs (cfg.logging.file != null) {
      file = cfg.logging.file;
    };

    # Note: heartbeat.every and maxConcurrent are managed by the wizard
    # (user-config.json) and deliberately omitted here so $include values
    # are not overridden by sibling keys.
    agents = {
      defaults = {
        workspace = cfg.workspace;
        memorySearch = {
          enabled = cfg.agents.defaults.memorySearch.enabled;
          sources = cfg.agents.defaults.memorySearch.sources;
          experimental = {
            sessionMemory = cfg.agents.defaults.memorySearch.experimental.sessionMemory;
          };
          provider = cfg.agents.defaults.memorySearch.provider;
          cache = {
            enabled = cfg.agents.defaults.memorySearch.cache.enabled;
            maxEntries = cfg.agents.defaults.memorySearch.cache.maxEntries;
          };
        } // lib.optionalAttrs (cfg.agents.defaults.memorySearch.local.modelPath != null) {
          local = {
            modelPath = cfg.agents.defaults.memorySearch.local.modelPath;
          };
        };
        contextPruning = {
          mode = cfg.agents.defaults.contextPruning.mode;
          ttl = cfg.agents.defaults.contextPruning.ttl;
        };
        compaction = {
          mode = cfg.agents.defaults.compaction.mode;
        };
        subagents = {
          maxConcurrent = cfg.agents.defaults.subagents.maxConcurrent;
        };
      } // lib.optionalAttrs (cfg.agents.defaults.heartbeat.model != null) {
        heartbeat = {
          model = cfg.agents.defaults.heartbeat.model;
        };
      };
    };

    hooks = {
      internal = {
        enabled = cfg.hooks.internal.enabled;
        entries = lib.mapAttrs (name: entry: {
          enabled = entry.enabled;
        }) cfg.hooks.internal.entries;
      };
    };
  } // lib.optionalAttrs (cfg.includeFile != null) {
    "$include" = cfg.includeFile;
  };

  configFile = pkgs.writeText "openclaw.json" (builtins.toJSON openclawConfig);

in {
  imports = [
    ./options/agents.nix
    ./options/browser.nix
    ./options/gateway.nix
    ./options/hooks.nix
    ./options/logging.nix
  ];

  # === Common options ===
  options.services.openclaw = {
    enable = lib.mkEnableOption "OpenClaw AI gateway";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The OpenClaw package to use";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/openclaw";
      description = "Data directory for OpenClaw";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "openclaw";
      description = "User to run OpenClaw as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "openclaw";
      description = "Group to run OpenClaw as";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for gateway port";
    };

    includeFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "${cfg.dataDir}/user-config.json";
      description = ''
        Path to additional JSON config file to merge.
        Use this for user-managed settings like API keys, models, and channels.
      '';
    };

    defaultUserConfig = lib.mkOption {
      type = lib.types.path;
      default = ./user-config.json;
      description = "Default user config template to copy on first boot";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to add to OpenClaw's PATH";
    };

    workspace = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/workspace";
      description = "Workspace directory for agent memory, identity, and session files";
    };
  };

  # === Service configuration ===
  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = lib.mkIf (cfg.user == "openclaw") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "openclaw") {};

    # Allow openclaw user to restart its own service (needed by setup wizard)
    security.sudo.extraRules = [{
      users = [ cfg.user ];
      commands = [{
        command = "/run/current-system/sw/bin/systemctl restart openclaw.service";
        options = [ "NOPASSWD" ];
      }];
    }];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Copy default user config on first boot if it doesn't exist
    system.activationScripts.openclawUserConfig = lib.stringAfter [ "users" ] ''
      if [ ! -f "${cfg.includeFile}" ]; then
        mkdir -p "$(dirname "${cfg.includeFile}")"
        cp "${cfg.defaultUserConfig}" "${cfg.includeFile}"
        chown ${cfg.user}:${cfg.group} "${cfg.includeFile}"
        chmod 600 "${cfg.includeFile}"
      fi
    '';

    systemd.services.openclaw = {
      description = "OpenClaw AI Gateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      path = [
        pkgs.nix
        pkgs.coreutils
        pkgs.bash
      ] ++ cfg.extraPackages;

      environment = {
        HOME = cfg.dataDir;
        OPENCLAW_CONFIG_PATH = toString configFile;
        OPENCLAW_STATE_DIR = cfg.dataDir;
        NPM_CONFIG_PREFIX = "${cfg.dataDir}/.npm-global";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'export PATH=\"${cfg.dataDir}/.npm-global/bin:$PATH\"; if [ ! -f ${cfg.dataDir}/.workspace-initialized ]; then ${cfg.package}/bin/openclaw setup --workspace ${cfg.workspace} && touch ${cfg.dataDir}/.workspace-initialized; fi'";
        ExecStart = "${pkgs.bash}/bin/bash -c 'export PATH=\"${cfg.dataDir}/.npm-global/bin:$PATH\" && exec ${cfg.package}/bin/openclaw gateway'";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ cfg.gateway.port ];
  };
}
