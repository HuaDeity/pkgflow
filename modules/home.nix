# Home Manager module for pkgflow
# Provides: home.packages
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.pkgflow;
  coreModule = import ./pkgflow.nix;

  isDarwin = pkgs.stdenv.isDarwin;
  wantsHome = builtins.elem "home" cfg.darwinPackagesSource;

  # Install if: (NOT Darwin) OR (Darwin AND "home" in darwinPackagesSource)
  shouldInstall = !isDarwin || (isDarwin && wantsHome);
in
{
  imports = [
    coreModule
  ];

  config =
    let
      cacheEnabled = cfg.caches.enable or false;
    in
    lib.mkMerge [
      # Install packages
      (lib.mkIf (cfg.manifestFile != null && shouldInstall) {
        home.packages = cfg._nixPackages;
      })

      # Set nix.package when using caches (required for home-manager)
      (lib.mkIf cacheEnabled {
        nix.package = lib.mkDefault pkgs.nix;
      })
    ];
}
