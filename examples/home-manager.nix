# Example: Home-manager standalone configuration
#
# This example shows how to use pkgflow with home-manager
# to automatically install packages from a Flox manifest.

{ inputs, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.homeModules.default
  ];

  # Option 1: Quick start with smart defaults (auto-detects manifest.toml)
  pkgflow.enable = true;
  pkgflow.manifest.flakeInputs = inputs;  # For flake package support

  # Option 2: Manual configuration with full control
  # pkgflow.manifestPackages = {
  #   enable = true;
  #   manifestFile = ./my-project/.flox/env/manifest.toml;
  #   flakeInputs = inputs;
  #   output = "home";  # Install to home.packages
  # };

  # Option 3: Global manifest path with override
  # pkgflow.manifest.file = ./default-manifest.toml;
  # pkgflow.manifestPackages = {
  #   enable = true;
  #   # manifestFile = ./override.toml;  # Optional override
  #   # requireSystemMatch = true;       # Strict system filtering
  # };

  # Rest of your home-manager configuration
  home = {
    username = "myuser";
    homeDirectory = "/home/myuser";
    stateVersion = "24.05";
  };
}
