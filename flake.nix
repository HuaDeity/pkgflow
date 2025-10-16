{
  description = "pkgflow - Universal package manifest transformer for Nix";

  outputs =
    { ... }:
    {
      # Shared module (just defines options, no imports)
      sharedModules.default = ./shared.nix;

      # Unified nix module (auto-detects home-manager vs system context)
      nixModules.default = ./home.nix;

      # Homebrew module (for Darwin homebrew.brews/casks)
      brewModules.default = ./darwin.nix;
    };
}
