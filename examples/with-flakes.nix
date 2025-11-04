# Example: Using flake packages from manifest with binary cache configuration
#
# This example shows how flake packages are automatically resolved
# from your flake inputs and how to configure binary caches.

{ inputs, ... }:

{
  imports = [
    inputs.pkgflow.homeModules.default  # or nixosModules.default, or darwinModules.default
  ];

  # Manifest files (can specify multiple)
  pkgflow.manifestFiles = [ ./manifest.toml ];

  # Install flake packages
  pkgflow.pkgs = {
    enable = true;
    flakes = [ "home" ];  # or [ "system" ] depending on your setup
  };

  # Configure binary caches for faster downloads
  pkgflow.substituters = {
    enable = true;
    context = "home";  # or "system"
    addNixCommunity = null;  # Auto-detect github:nix-community/* flakes
  };

  # Override or add custom cache mappings:
  # pkgflow.substituters.mappingOverrides = [
  #   # Override default helix cache
  #   {
  #     flake = "github:helix-editor/helix";
  #     substituter = "https://my-custom-cache.org";
  #     trustedKey = "my-cache.org-1:customkey==";
  #   }
  #   # Add mapping for your own flake
  #   {
  #     flake = "github:myorg/myflake";
  #     substituter = "https://myflake.cachix.org";
  #     trustedKey = "myflake.cachix.org-1:key==";
  #   }
  # ];

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
  # Binary caches are automatically configured based on the mapping in
  # config/caches.nix - for example, helix uses helix.cachix.org
}
