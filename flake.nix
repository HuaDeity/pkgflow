{
  description = "pkgflow - Universal package manifest transformer for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {
    # Unified module set (works across all platforms)
    nixosModules = {
      default = ./default.nix;
      manifestPackages = ./home.nix;
      homebrewManifest = ./darwin.nix;
      shared = ./shared.nix;
    };

    # Aliases for convenience and backward compatibility
    homeModules = self.nixosModules;
    darwinModules = self.nixosModules;
    homeManagerModules = self.nixosModules;
  };
}
