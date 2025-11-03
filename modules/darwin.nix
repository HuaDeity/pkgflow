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
    builtins.elem "system" cfg.darwinPackagesSource ||
    builtins.elem "system" cfg.flakePackagesSource;

  wantsBrew =
    builtins.elem "brew" cfg.darwinPackagesSource ||
    builtins.elem "brew" cfg.flakePackagesSource;
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
    (lib.mkIf (wantsSystem && cfg.manifestFile != null) {
      environment.systemPackages = cfg._nixPackages;
    })

    # Install via Homebrew (when "brew" in sources)
    (lib.mkIf wantsBrew {
      homebrew.brews = cfg._homebrewFormulas;
      homebrew.casks = cfg._homebrewCasks;
    })
  ];
}
