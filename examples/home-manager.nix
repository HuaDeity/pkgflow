# Example: Home-manager standalone configuration
#
# This example shows how to use pkgflow with home-manager
# to automatically install packages from a Flox manifest.

{ inputs, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.sharedModules.default  # Optional: for global config
    inputs.pkgflow.nixModules.default     # Auto-detects home.packages
  ];

  # Shared manifest path (recommended for multiple modules)
  pkgflow.manifest.file = ./my-project/.flox/env/manifest.toml;

  # Optional: Override manifest for this specific module
  # pkgflow.manifestPackages.manifestFile = ./custom-manifest.toml;

  # Optional: Only install packages that explicitly declare systems
  # pkgflow.manifestPackages.requireSystemMatch = true;

  # Rest of your home-manager configuration
  home = {
    username = "myuser";
    homeDirectory = "/home/myuser";
    stateVersion = "24.05";
  };
}
