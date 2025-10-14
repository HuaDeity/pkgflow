# Example: NixOS system configuration
#
# This example shows how to use flox-manifest-nix in a NixOS system
# configuration to install packages to environment.systemPackages.

{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.flox-manifest.nixosModules.default
  ];

  # Set global manifest path
  flox.manifest.file = /etc/nixos/manifest.toml;

  # Enable manifest package installation to system packages
  flox.manifestPackages = {
    enable = true;
    flakeInputs = inputs;
    output = "system";  # Install to environment.systemPackages
  };

  # Rest of your NixOS configuration
  system.stateVersion = "24.05";
}
