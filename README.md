# nixos-openclaw
NixOS Openclaw package and modules

## Goal
- Create ready to run out-of-the-box nixos configurations that have openclaw already installed, configured and can be used from non-technical users

## Current State
- openclaw package (including web UI) working
- basic functionality working (you can run it manually and then edit ~/.openclaw/openclaw.json for configuration)

## Next steps
- More openclaw dependencies will be added, needed for skill installation, memory local embeddings, etc.
- This repo will be populated with a NixOS module with configuration options for running openclaw gateway as a systemd service
- NixOS configurations will be added for small devices (Rpi4, Rpi5, Nanopi). Openclaw is pretty lightweight and can run easily on them

