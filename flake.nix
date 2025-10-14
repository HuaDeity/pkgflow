{
  description = "pkgflow - Universal package manifest transformer for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {
    # Home-manager modules
    homeModules = {
      default = ./default.nix;
      manifestPackages = ./home.nix;
      shared = ./shared.nix;
    };

    # NixOS modules
    nixosModules = {
      default = ./default.nix;
      manifestPackages = ./home.nix;
      shared = ./shared.nix;
    };

    # Darwin modules
    darwinModules = {
      default = import ./darwin-default.nix;
      homebrewManifest = ./darwin.nix;
      shared = ./shared.nix;
    };

    # Legacy attribute for backward compatibility
    homeManagerModules = self.homeModules;
  };
}
