# nix-darwin module for pkgflow
# Provides: environment.systemPackages (or homebrew.brews/casks)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.pkgflow;
  coreModule = import ./pkgflow.nix;

  # Determine if we want system-level installation
  wantsSystem =
    cfg.pkgs.enable && (
      builtins.elem "system" cfg.pkgs.nixpkgs ||
      builtins.elem "system" cfg.pkgs.flakes
    );

  wantsBrew =
    cfg.pkgs.enable && (
      builtins.elem "brew" cfg.pkgs.nixpkgs ||
      builtins.elem "brew" cfg.pkgs.flakes
    );
in
{
  imports = [
    coreModule
  ];

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = pkgs.stdenv.isDarwin;
          message = ''
            pkgflow (darwin module): This module is only for macOS/Darwin.
            For other platforms, use nixosModules.default instead.
          '';
        }
      ];
    }

    # Install Nix packages via systemPackages (when "system" in sources)
    (lib.mkIf wantsSystem {
      environment.systemPackages = cfg._nixPackages;
    })

    # Install via Homebrew (when "brew" in sources)
    (lib.mkIf wantsBrew {
      homebrew.brews = cfg._homebrewFormulas;
      homebrew.casks = cfg._homebrewCasks;
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
