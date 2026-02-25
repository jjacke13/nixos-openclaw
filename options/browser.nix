{ lib, pkgs, ... }:
{
  options.services.openclaw.browser = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable browser automation";
        };

        executablePath = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.chromium}/bin/chromium-browser";
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
}
