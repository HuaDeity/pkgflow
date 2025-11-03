# NixOS module for pkgflow
# Provides: environment.systemPackages
{
  config,
  lib,
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

  config = lib.mkIf (cfg.manifestFile != null || (cfg ? manifest && cfg.manifest.file != null)) {
    environment.systemPackages = cfg._packages;
  };
}
