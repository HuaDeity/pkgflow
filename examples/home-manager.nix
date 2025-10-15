# Example: Home-manager standalone configuration
#
# This example shows how to use pkgflow with home-manager
# to automatically install packages from a Flox manifest.

{ inputs, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.homeModules.default
  ];

  # Recommended: Set global configuration
  pkgflow.manifest = {
    file = ./my-project/.flox/env/manifest.toml;
    flakeInputs = inputs;  # For flake package support
  };

  # Enable package installation to home.packages
  pkgflow.manifestPackages = {
    enable = true;
    # output = "home";  # Default - installs to home.packages
  };

  # Alternative: Direct configuration without global settings
  # pkgflow.manifestPackages = {
  #   enable = true;
  #   manifestFile = ./manifest.toml;
  #   flakeInputs = inputs;
  #   requireSystemMatch = true;  # Optional: strict system filtering
  # };

  # Rest of your home-manager configuration
  home = {
    username = "myuser";
    homeDirectory = "/home/myuser";
    stateVersion = "24.05";
  };
}
