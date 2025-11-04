# Example: Home-manager standalone configuration
#
# This example shows how to use pkgflow with home-manager
# to automatically install packages from a Flox manifest.

{ inputs, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.homeModules.pkgflow
  ];

  # Manifest files (can specify multiple)
  pkgflow.manifestFiles = [ ./my-project/.flox/env/manifest.toml ];

  # Package installation (enabled by default)
  pkgflow.pkgs = {
    enable = true;
    nixpkgs = [ "home" ];  # Install via home.packages
    flakes = [ "home" ];
  };

  # Binary cache configuration (optional)
  # pkgflow.substituters = {
  #   enable = true;
  #   context = "home";  # Use extra-substituters/extra-trusted-public-keys
  # };

  # Rest of your home-manager configuration
  home = {
    username = "myuser";
    homeDirectory = "/home/myuser";
    stateVersion = "24.05";
  };
}
