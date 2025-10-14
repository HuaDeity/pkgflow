# Example: Using flake packages from manifest
#
# This example shows how to configure flake package resolution
# for packages defined with the 'flake' attribute in manifest.toml.

{ inputs, ... }:

{
  imports = [
    inputs.flox-manifest.homeModules.default
  ];

  flox.manifestPackages = {
    enable = true;
    manifestFile = ./manifest.toml;

    # IMPORTANT: Pass your flake inputs to resolve flake packages
    flakeInputs = inputs;
  };

  # Your manifest.toml should have entries like:
  #
  # [install]
  # helix.flake = "github:helix-editor/helix"
  # helix.systems = ["x86_64-linux", "aarch64-darwin"]
  #
  # neovim-nightly.flake = "github:nix-community/neovim-nightly-overlay"
  #
  # For this to work, make sure your flake.nix includes these as inputs:
  #
  # inputs = {
  #   helix.url = "github:helix-editor/helix";
  #   neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  # };
}
