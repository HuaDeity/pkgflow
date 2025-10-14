# Example: nix-darwin configuration with Homebrew
#
# This example shows how to use flox-manifest-nix on macOS with nix-darwin
# to convert Nix packages to Homebrew formulae and casks.

{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.flox-manifest.darwinModules.default
  ];

  # Set global manifest path
  flox.manifest.file = ~/.config/flox/manifest.toml;

  # Option 1: Install as Nix packages to system
  flox.manifestPackages = {
    enable = true;
    flakeInputs = inputs;
    output = "system";
  };

  # Option 2: Convert to Homebrew packages (alternative to above)
  # flox.homebrewManifest = {
  #   enable = true;
  #   # Custom mapping file if needed
  #   # mappingFile = ./my-nix-to-brew-mapping.toml;
  # };

  # Rest of your nix-darwin configuration
  system.stateVersion = 6;
}
