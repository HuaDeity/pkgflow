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

  # Determine if we should install via home
  # On Darwin: only if "home" is specified in sources
  # On non-Darwin: always (assumes standalone home-manager, not with NixOS system module)
  wantsHome =
    if !isDarwin then
      true
    else
      builtins.elem "home" cfg.darwinPackagesSource || builtins.elem "home" cfg.flakePackagesSource;
in
{
  imports = [
    coreModule
  ];

  config =
    let
      cacheEnabled = cfg.caches.enable or false;
      cacheIsHome = cfg._effectiveInstallContext == "home";
    in
    lib.mkMerge [
      # Install packages
      (lib.mkIf (cfg.manifestFile != null && wantsHome) {
        home.packages = cfg._nixPackages;
      })

      # Binary cache configuration - home level
      (lib.mkIf (cacheEnabled && cfg._cacheResult.hasMatches && cacheIsHome) {
        nix.settings = {
          substituters = cfg._cacheResult.substituters;
          trusted-public-keys = cfg._cacheResult.trustedKeys;
        };
      })
    ];
}
