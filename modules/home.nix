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
  coreModule = import ../core.nix;

  isDarwin = pkgs.stdenv.isDarwin;
  hasDarwinSources = isDarwin && (builtins.length cfg.darwinPackagesSource) > 0;
  wantsHome = hasDarwinSources && builtins.elem "home" cfg.darwinPackagesSource;

  # Choose which packages to install
  # On Darwin with darwinPackagesSource including "home": use filtered _homePackages
  # Otherwise: use all _packages
  packagesToInstall = if wantsHome then cfg._homePackages else cfg._packages;
in
{
  imports = [
    coreModule
  ];

  config =
    let
      manifestFile = if cfg.manifestFile != null then cfg.manifestFile else (cfg.manifest.file or null);
      cacheEnabled = cfg.caches.enable or false;
    in
    lib.mkMerge [
      # Install packages
      (lib.mkIf (manifestFile != null) {
        home.packages = packagesToInstall;
      })

      # Set nix.package when using caches (required for home-manager)
      (lib.mkIf cacheEnabled {
        nix.package = lib.mkDefault pkgs.nix;
      })
    ];
}
