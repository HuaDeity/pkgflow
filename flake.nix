{
  description = "pkgflow - Universal package manifest transformer for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      # Shared module (just defines options, no imports)
      sharedModules.default = ./shared.nix;

      # Home-manager module (for home.packages)
      homeModules.default = import ./home.nix { _outputTarget = "home"; };

      systemModules.default = import ./home.nix { _outputTarget = "system"; };

      # Homebrew module (for Darwin homebrew.brews/casks)
      brewModules.default = ./darwin.nix;
    };
}
