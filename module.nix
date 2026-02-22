# NixOS module for OpenClaw
#
# Philosophy: Build JSON config from Nix options using submodules.
# Start minimal, add options progressively.

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
    agents = {
      defaults = {
        workspace = cfg.workspace;
      };
    };
  } // lib.optionalAttrs (cfg.includeFile != null) {
    "$include" = cfg.includeFile;
  };

  configFile = pkgs.writeText "openclaw.json" (builtins.toJSON openclawConfig);

in {
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

    # === Logging ===
    logging = lib.mkOption {
      type = lib.types.submodule {
        options = {
          level = lib.mkOption {
            type = lib.types.enum [ "trace" "debug" "info" "warn" "error" ];
            default = "info";
            description = "Log level";
          };

          file = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Log file path";
          };

          consoleLevel = lib.mkOption {
            type = lib.types.enum [ "trace" "debug" "info" "warn" "error" ];
            default = "info";
            description = "Console log level";
          };

          consoleStyle = lib.mkOption {
            type = lib.types.enum [ "pretty" "compact" "json" ];
            default = "pretty";
            description = "Console log style";
          };

          redactSensitive = lib.mkOption {
            type = lib.types.enum [ "off" "tools" ];
            default = "tools";
            description = "Redact sensitive data in logs";
          };

          redactPatterns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "\\bTOKEN\\b\\s*[=:]\\s*([\"']?)([^\\s\"']+)\\1" ];
            description = "Regex patterns for redaction";
          };
        };
      };
      default = { };
      description = "Logging configuration";
    };

    # === Browser ===
    browser = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable browser automation";
          };

          executablePath = lib.mkOption {
            type = lib.types.str;
            default = "${pkgs.chromium}/bin/chromium";
            description = "Path to browser executable";
          };

          headless = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Run browser in headless mode";
          };

          noSandbox = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Disable browser sandbox (required for some setups)";
          };

          attachOnly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Only attach to existing browser, don't launch";
          };

          defaultProfile = lib.mkOption {
            type = lib.types.str;
            default = "openclaw";
            description = "Default browser profile name";
          };

          color = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Browser highlight color (hex)";
          };

          remoteCdpTimeoutMs = lib.mkOption {
            type = lib.types.int;
            default = 1500;
            description = "Remote CDP HTTP timeout (ms)";
          };

          remoteCdpHandshakeTimeoutMs = lib.mkOption {
            type = lib.types.int;
            default = 3000;
            description = "Remote CDP WebSocket handshake timeout (ms)";
          };

          profiles = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                cdpPort = lib.mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "CDP port for this profile";
                };

                cdpUrl = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "CDP URL for remote browser";
                };

                color = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Profile highlight color (hex)";
                };
              };
            });
            default = { };
            description = "Browser profiles";
          };
        };
      };
      default = { };
      description = "Browser automation configuration";
    };

    # === Gateway ===
    gateway = lib.mkOption {
      type = lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 18789;
            description = "Gateway server port";
          };

          mode = lib.mkOption {
            type = lib.types.enum [ "local" "remote" ];
            default = "local";
            description = "Gateway mode";
          };

          bind = lib.mkOption {
            type = lib.types.enum [ "loopback" "lan" "tailnet" "auto" "custom" ];
            default = "loopback";
            description = "Network interface binding";
          };

          auth = lib.mkOption {
            type = lib.types.submodule {
              options = {
                mode = lib.mkOption {
                  type = lib.types.enum [ "none" "token" "password" ];
                  default = "none";
                  description = "Authentication mode";
                };

                token = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Auth token (for mode = token)";
                };

                password = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Auth password (for mode = password)";
                };
              };
            };
            default = { };
            description = "Authentication settings";
          };

          tailscale = lib.mkOption {
            type = lib.types.submodule {
              options = {
                mode = lib.mkOption {
                  type = lib.types.enum [ "off" "serve" "funnel" ];
                  default = "off";
                  description = "Tailscale exposure mode";
                };

                resetOnExit = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Reset Tailscale serve/funnel on shutdown";
                };
              };
            };
            default = { };
            description = "Tailscale settings";
          };
        };
      };
      default = { };
      description = "Gateway configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = {};

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
        PATH = "${cfg.dataDir}/.npm-global/bin:$PATH";  # prepend npm-global to systemd path
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'if [ ! -f ${cfg.dataDir}/.workspace-initialized ]; then ${cfg.package}/bin/openclaw setup --workspace ${cfg.workspace} && touch ${cfg.dataDir}/.workspace-initialized; fi'";
        ExecStart = "${cfg.package}/bin/openclaw gateway";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ cfg.gateway.port ];
  };
}
