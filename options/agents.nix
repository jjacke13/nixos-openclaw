{ lib, ... }:
{
  # Note: model.primary, heartbeat.every, and maxConcurrent are managed
  # by the setup wizard via user-config.json ($include).
  options.services.openclaw.agents = lib.mkOption {
    type = lib.types.submodule {
      options = {
        defaults = lib.mkOption {
          type = lib.types.submodule {
            options = {
              memorySearch = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    enabled = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Enable memory search";
                    };
                    sources = lib.mkOption {
                      type = lib.types.listOf (lib.types.enum [ "memory" "sessions" ]);
                      default = [ "memory" "sessions" ];
                      description = "Memory search sources";
                    };
                    experimental = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          sessionMemory = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Enable experimental session memory";
                          };
                        };
                      };
                      default = { };
                      description = "Experimental memory search features";
                    };
                    provider = lib.mkOption {
                      type = lib.types.enum [ "local" "openai" ];
                      default = "local";
                      description = "Embedding provider for memory search";
                    };
                    local = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          modelPath = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Path to embedding model GGUF file for local memory search";
                          };
                        };
                      };
                      default = { };
                      description = "Local embedding model configuration";
                    };
                    cache = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          enabled = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Enable memory search cache";
                          };
                          maxEntries = lib.mkOption {
                            type = lib.types.int;
                            default = 50000;
                            description = "Maximum cache entries";
                          };
                        };
                      };
                      default = { };
                      description = "Memory search cache settings";
                    };
                  };
                };
                default = { };
                description = "Memory search configuration";
              };

              contextPruning = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    mode = lib.mkOption {
                      type = lib.types.enum [ "off" "cache-ttl" ];
                      default = "cache-ttl";
                      description = "Context pruning mode";
                    };
                    ttl = lib.mkOption {
                      type = lib.types.str;
                      default = "1h";
                      description = "Pruning TTL duration (e.g. 30m, 1h)";
                    };
                  };
                };
                default = { };
                description = "Context pruning configuration";
              };

              compaction = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    mode = lib.mkOption {
                      type = lib.types.enum [ "default" "safeguard" ];
                      default = "safeguard";
                      description = "Compaction mode (safeguard uses chunked summarization)";
                    };
                  };
                };
                default = { };
                description = "Compaction configuration";
              };

              heartbeat = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    model = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Model for heartbeat runs (e.g. provider/model-name). Interval (every) is set via the wizard.";
                    };
                  };
                };
                default = { };
                description = "Heartbeat configuration. Note: 'every' is managed by the setup wizard.";
              };

              subagents = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    maxConcurrent = lib.mkOption {
                      type = lib.types.int;
                      default = 8;
                      description = "Maximum concurrent subagent runs";
                    };
                  };
                };
                default = { };
                description = "Subagent configuration";
              };
            };
          };
          default = { };
          description = "Agent default settings";
        };
      };
    };
    default = { };
    description = "Agent configuration";
  };
}
