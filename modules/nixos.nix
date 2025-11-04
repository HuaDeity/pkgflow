# NixOS module for pkgflow
# Provides: environment.systemPackages
{
  config,
  lib,
  ...
}:

let
  cfg = config.pkgflow;
  coreModule = import ./pkgflow.nix;
in
{
  imports = [
    coreModule
  ];

  config = lib.mkMerge [
    # Install packages
    (lib.mkIf cfg.pkgs.enable {
      environment.systemPackages = cfg._nixPackages;
    })

    # Binary cache configuration - system level (onlyTrusted)
    (lib.mkIf (cfg.substituters.enable && cfg._cacheResult.hasMatches && cfg.substituters.onlyTrusted) {
      nix.settings = {
        trusted-substituters = cfg._cacheResult.substituters;
        trusted-public-keys = cfg._cacheResult.trustedKeys;
      };
    })

    # Binary cache configuration - system level (context = "system")
    (lib.mkIf (cfg.substituters.enable && cfg._cacheResult.hasMatches && cfg.substituters.context == "system") {
      nix.settings = {
        substituters = cfg._cacheResult.substituters;
        trusted-public-keys = cfg._cacheResult.trustedKeys;
      };
    })
  ];
}
