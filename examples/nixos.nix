# Example: NixOS system configuration
#
# This example shows how to use pkgflow in a NixOS system
# configuration to install packages to environment.systemPackages.

{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.nixosModules.default
  ];

  # Manifest files (can specify multiple)
  pkgflow.manifestFiles = [ /etc/nixos/manifest.toml ];

  # Package installation (enabled by default)
  # On NixOS, pkgs.nixpkgs is ignored - packages always go to environment.systemPackages
  pkgflow.pkgs = {
    enable = true;
    flakes = [ "system" ];  # Install flake packages via environment.systemPackages
  };

  # Binary cache configuration (optional)
  # pkgflow.substituters = {
  #   enable = true;
  #   context = "system";  # Use substituters/trusted-public-keys
  # };

  # Rest of your NixOS configuration
  system.stateVersion = "24.05";
}
