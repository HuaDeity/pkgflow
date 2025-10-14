# Example: Complete flake.nix using flox-manifest-nix

{
  description = "Example flake using flox-manifest-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add flox-manifest-nix
    flox-manifest = {
      url = "github:yourusername/flox-manifest-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add any flake packages referenced in your manifest
    helix = {
      url = "github:helix-editor/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, flox-manifest, ... }@inputs: {
    # Home-manager configuration
    homeConfigurations."user@laptop" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      modules = [
        flox-manifest.homeModules.default

        {
          home.username = "user";
          home.homeDirectory = "/home/user";
          home.stateVersion = "24.05";

          # Configure manifest package installation
          flox.manifestPackages = {
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
        flox-manifest.nixosModules.default
        ./hardware-configuration.nix

        {
          # System configuration
          flox.manifestPackages = {
            enable = true;
            manifestFile = ./system-manifest.toml;
            flakeInputs = inputs;
            output = "system";
          };

          system.stateVersion = "24.05";
        }
      ];
    };
  };
}
