{
  description = "pkgflow - Universal package manifest transformer for Nix";

  outputs =
    { ... }:
    {
      # NixOS modules
      nixosModules.pkgflow = ./modules/nixos.nix;

      # nix-darwin modules
      darwinModules.pkgflow = ./modules/darwin.nix;

      # Home-manager modules
      homeModules.pkgflow = ./modules/home.nix;
    };
}
