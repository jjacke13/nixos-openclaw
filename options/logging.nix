{ lib, ... }:
{
  options.services.openclaw.logging = lib.mkOption {
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
}
