# Example: Complete flake.nix using pkgflow

{
  description = "Example flake using pkgflow";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add pkgflow
    pkgflow = {
      url = "github:HuaDeity/pkgflow";
    };

    # Add any flake packages referenced in your manifest
    helix = {
      url = "github:helix-editor/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      pkgflow,
      ...
    }@inputs:
    {
      # Home-manager configuration
      homeConfigurations."user@laptop" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;

        modules = [
          pkgflow.nixModules.default # Auto-detects home.packages

          {
            home.username = "user";
            home.homeDirectory = "/home/user";
            home.stateVersion = "24.05";

            # Configure manifest package installation
            pkgflow.manifestPackages.manifestFile = ./manifest.toml;
          }
        ];
      };

      # NixOS configuration
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          pkgflow.nixModules.default # Auto-detects environment.systemPackages
          ./hardware-configuration.nix

          {
            # System configuration
            pkgflow.manifestPackages.manifestFile = ./system-manifest.toml;

            system.stateVersion = "24.05";
          }
        ];
      };
    };
}
