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

  config = lib.mkIf (cfg.manifestFile != null) {
    environment.systemPackages = cfg._nixPackages;
  };
}
