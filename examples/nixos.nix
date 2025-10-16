# Example: NixOS system configuration
#
# This example shows how to use pkgflow in a NixOS system
# configuration to install packages to environment.systemPackages.

{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.sharedModules.default
    inputs.pkgflow.nixModules.default  # Auto-detects environment.systemPackages
  ];

  # Set global manifest path
  pkgflow.manifest.file = /etc/nixos/manifest.toml;

  # Optional: Override or configure per-module
  # pkgflow.manifestPackages.manifestFile = /etc/nixos/custom-manifest.toml;
  # pkgflow.manifestPackages.requireSystemMatch = true;

  # Rest of your NixOS configuration
  system.stateVersion = "24.05";
}
