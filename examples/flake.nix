# Example: Complete flake.nix using pkgflow-nix

{
  description = "Example flake using pkgflow-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add pkgflow-nix
    pkgflow = {
      url = "github:yourusername/pkgflow-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add any flake packages referenced in your manifest
    helix = {
      url = "github:helix-editor/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, pkgflow, ... }@inputs: {
    # Home-manager configuration
    homeConfigurations."user@laptop" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      modules = [
        pkgflow.homeModules.default

        {
          home.username = "user";
          home.homeDirectory = "/home/user";
          home.stateVersion = "24.05";

          # Configure manifest package installation
          pkgflow.manifestPackages = {
            enable = true;
            manifestFile = ./manifest.toml;
            flakeInputs = inputs;
          };
        }
      ];
    };

    # NixOS configuration
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        pkgflow.nixosModules.default
        ./hardware-configuration.nix

        {
          # System configuration
          pkgflow.manifestPackages = {
            enable = true;
            manifestFile = ./system-manifest.toml;
            flakeInputs = inputs;
            # Installs to environment.systemPackages automatically
          };

          system.stateVersion = "24.05";
        }
      ];
    };
  };
}
