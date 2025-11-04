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
      cfg.pkgs.enable
    else
      cfg.pkgs.enable && (builtins.elem "home" cfg.pkgs.nixpkgs || builtins.elem "home" cfg.pkgs.flakes);
in
{
  imports = [
    coreModule
  ];

  config =
    let
      substitutersEnabled = cfg.substituters.enable or false;
      substitutersIsHome = cfg.substituters.context == "home";
    in
    lib.mkMerge [
      # Install packages
      (lib.mkIf wantsHome {
        home.packages = cfg._nixPackages;
      })

      # Binary cache configuration - home level
      (lib.mkIf (substitutersEnabled && cfg._cacheResult.hasMatches && substitutersIsHome) {
        nix.settings = {
          extra-substituters = cfg._cacheResult.substituters;
          extra-trusted-public-keys = cfg._cacheResult.trustedKeys;
        };
      })
    ];
}
