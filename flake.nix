{
  description = "pkgflow - Universal package manifest transformer for Nix";

  outputs =
    { ... }:
    {
      # Shared module (defines manifest.file option)
      sharedModules.default = ./shared.nix;

      # NixOS modules
      nixosModules = {
        default = ./modules/nixos.nix;
        nixos = ./modules/nixos.nix;
      };

      # nix-darwin modules
      darwinModules = {
        default = ./modules/darwin.nix;
        darwin = ./modules/darwin.nix;
        # Legacy homebrew-only module (deprecated)
        homebrew = ./homebrew.nix;
      };

      # home-manager modules
      homeModules = {
        default = ./modules/home.nix;
        home = ./modules/home.nix;
      };

      # Backward compatibility aliases
      nixModules.default = ./modules/home.nix; # Old unified module
      brewModules.default = ./homebrew.nix; # Old homebrew module
    };
}
