{ lib, ... }:
{
  options.services.openclaw.hooks = lib.mkOption {
    type = lib.types.submodule {
      options = {
        internal = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enabled = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable internal hooks";
              };

              entries = lib.mkOption {
                type = lib.types.attrsOf (lib.types.submodule {
                  options = {
                    enabled = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Enable this hook";
                    };
                  };
                });
                default = {
                  bootstrap-extra-files.enabled = true;
                  boot-md.enabled = true;
                  command-logger.enabled = true;
                  session-memory.enabled = true;
                };
                description = "Internal hook entries";
              };
            };
          };
          default = { };
          description = "Internal hooks configuration";
        };
      };
    };
    default = { };
    description = "Hooks configuration";
  };
}
