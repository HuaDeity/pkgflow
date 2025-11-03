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
        home.packages = cfg._packages;
      })

      # Set nix.package when using caches (required for home-manager)
      (lib.mkIf cacheEnabled {
        nix.package = lib.mkDefault pkgs.nix;
      })
    ];
}
