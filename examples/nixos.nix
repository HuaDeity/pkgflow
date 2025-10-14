# Example: NixOS system configuration
#
# This example shows how to use pkgflow-nix in a NixOS system
# configuration to install packages to environment.systemPackages.

{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.nixosModules.default
  ];

  # Set global manifest path
  pkgflow.manifest.file = /etc/nixos/manifest.toml;

  # Enable manifest package installation to system packages
  pkgflow.manifestPackages = {
    enable = true;
    flakeInputs = inputs;
    output = "system";  # Install to environment.systemPackages
  };

  # Rest of your NixOS configuration
  system.stateVersion = "24.05";
}
