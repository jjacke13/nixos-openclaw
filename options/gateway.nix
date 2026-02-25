{ lib, ... }:
{
  options.services.openclaw.gateway = lib.mkOption {
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
}
