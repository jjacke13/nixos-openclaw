{
  description = "A flake to produce Openclaw package, modules and nixos configurations for NiXOS";
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }@inputs:

  {
    packages = {
      x86_64-linux = {
        openclaw = import ./package.nix { pkgs=nixpkgs.legacyPackages.x86_64-linux; };
        default = self.packages.x86_64-linux.openclaw;
      };
      
      aarch64-linux = {
        openclaw = import ./package.nix { pkgs=nixpkgs.legacyPackages.aarch64-linux; };
        default = self.packages.aarch64-linux.openclaw;
      };
    };

    nixosModules = {
     ## To be added 
    };
    
    nixosConfigurations= {
     ## To be added     
    };
  };
}

