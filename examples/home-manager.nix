# Example: Home-manager standalone configuration
#
# This example shows how to use pkgflow-nix with home-manager
# to automatically install packages from a Flox manifest.

{ inputs, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.homeModules.default
  ];

  # Set global manifest path (optional)
  pkgflow.manifest.file = ./my-project/.flox/env/manifest.toml;

  # Enable manifest package installation
  pkgflow.manifestPackages = {
    enable = true;
    # manifestFile = ./custom-manifest.toml;  # Override global path if needed

    # Pass flake inputs to resolve flake-based packages
    flakeInputs = inputs;

    # Only install packages that list this system in their 'systems' array
    # requireSystemMatch = true;

    # Where to install packages (home or system)
    output = "home";  # Install to home.packages
  };

  # Rest of your home-manager configuration
  home = {
    username = "myuser";
    homeDirectory = "/home/myuser";
    stateVersion = "24.05";
  };
}
