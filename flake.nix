{
  description = "pkgflow - Universal package manifest transformer for Nix";

  outputs =
    { ... }:
    {
      # NixOS modules
      nixosModules = rec {
        pkgflow = ./modules/nixos.nix;
        default = pkgflow;
      };

      darwinModules = rec {
        pkgflow = ./modules/darwin.nix;
        default = pkgflow;
      };

      homeManagerModules = rec {
        pkgflow = ./modules/home.nix;
        default = pkgflow;
      };
    };
}
