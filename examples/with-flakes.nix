# Example: Using flake packages from manifest
#
# This example shows how flake packages are automatically resolved
# from your flake inputs. No manual configuration needed!

{ inputs, ... }:

{
  imports = [
    inputs.pkgflow.nixModules.default
  ];

  pkgflow.manifestPackages.manifestFile = ./manifest.toml;

  # That's it! pkgflow automatically uses your flake's inputs
  # to resolve flake-based packages in the manifest.

  # Your manifest.toml should have entries like:
  #
  # [install]
  # helix.flake = "github:helix-editor/helix"
  # helix.systems = ["x86_64-linux", "aarch64-darwin"]
  #
  # mcp-hub.flake = "github:ravitemer/mcp-hub"
  # mcp-hub.systems = ["aarch64-darwin"]
  #
  # For this to work, make sure your flake.nix includes these as inputs:
  #
  # inputs = {
  #   helix.url = "github:helix-editor/helix";
  #   helix.inputs.nixpkgs.follows = "nixpkgs";
  #
  #   mcp-hub.url = "github:ravitemer/mcp-hub";
  #   mcp-hub.inputs.nixpkgs.follows = "nixpkgs";
  # };
  #
  # If a flake package is not found in inputs, pkgflow will show a helpful error:
  #
  # pkgflow: Flake package 'helix' not found in flake inputs.
  #
  # The manifest references: helix.flake = "github:helix-editor/helix"
  # But 'helix' is not available in your flake inputs.
  #
  # To fix this, add to your flake.nix:
  #   inputs.helix.url = "github:helix-editor/helix";
  #   inputs.helix.inputs.nixpkgs.follows = "nixpkgs";
  #
  # Then run: nix flake update helix
}
