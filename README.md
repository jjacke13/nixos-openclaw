# nixos-openclaw
NixOS Openclaw package and modules

## Goal
- Create ready to run out-of-the-box nixos configurations that have openclaw already installed, configured and can be used from non-technical users

## Current State
- openclaw package (including web UI) working
- memory local embeddings working out of the box when running the package manually
- default nixos module currently under testing
- wizard module currently under testing

## Installation

### Using the module
Add the module to your NixOS flake:
```nix
# flake.nix
{
  inputs.nixos-openclaw.url = "github:jjacke13/nixos-openclaw";

  outputs = { self, nixos-openclaw }: {
    nixosConfigurations.yourHost = lib.nixosSystem {
      modules = [
        nixos-openclaw.nixosModules.openclaw
        nixos-openclaw.nixosModules.openclaw-wizard
        ./configuration.nix
      ];
    };
  };
}
```

### Basic configuration
```nix
services.openclaw = {
  enable = true;
  openFirewall = true;
};

services.openclaw-wizard = {
  enable = true;
  openFirewall = true;
};
```

## Wizard Module

The wizard provides a web-based UI for configuring OpenClaw settings without editing JSON files manually.

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `services.openclaw-wizard.enable` | boolean | false | Enable the wizard web UI |
| `services.openclaw-wizard.host` | string | "0.0.0.0" | Address the wizard binds to |
| `services.openclaw-wizard.port` | port | 8080 | Port the wizard listens on |
| `services.openclaw-wizard.openFirewall` | boolean | false | Open firewall for wizard port |
| `services.openclaw-wizard.configPath` | string | `${openclaw.dataDir}/user-config.json` | Path to user-config.json |
| `services.openclaw-wizard.ppqCreditPath` | string | `${openclaw.dataDir}/ppq-credit.json` | Path to PPQ credit file |

### Features
- Edit API keys, models, and channel configurations
- PPQ account management (credit file handling)
- Auto-restarts OpenClaw service after saving
- Internationalization: English and Greek

### Usage
After enabling, access the wizard at `http://<host>:<port>` to configure:
- Agent settings and models
- API keys and authentication
- Telegram and other channel integrations

## Next steps
- More openclaw dependencies will be added, needed for skill installation etc.
- More options will be added to the nixos module
- NixOS configurations will be added for small devices (Rpi4, Rpi5, Nanopi). Openclaw is pretty lightweight and can run easily on them

