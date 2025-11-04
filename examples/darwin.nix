# Example: nix-darwin configuration
#
# This example shows recommended patterns for using pkgflow on macOS
# with nix-darwin to manage packages via Nix and/or Homebrew.

{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.darwinModules.pkgflow
  ];

  # Manifest files (can specify multiple for merging)
  pkgflow.manifestFiles = [ ./manifest.toml ];
  # Example with multiple manifests:
  # pkgflow.manifestFiles = [
  #   ./project-a/manifest.toml
  #   ./project-b/manifest.toml
  # ];

  # ========================================
  # RECOMMENDED: Strategy 1 - Homebrew-First
  # ========================================
  # Use Homebrew for most packages, Nix via home-manager for packages unavailable in Homebrew
  pkgflow.pkgs = {
    enable = true;
    nixpkgs = [ "brew" "home" ];  # Prefer brew, fallback to home
    flakes = [ "brew" "home" ];   # Same for flake packages
  };

  # ========================================
  # Alternative: Strategy 2 - System-level Nix
  # ========================================
  # Install Nix packages via environment.systemPackages
  # pkgflow.pkgs = {
  #   enable = true;
  #   nixpkgs = [ "system" ];
  #   flakes = [ "system" ];
  # };

  # ========================================
  # Alternative: Strategy 3 - Homebrew + System
  # ========================================
  # Use Homebrew for packages that support it, system packages for others
  # pkgflow.pkgs = {
  #   enable = true;
  #   nixpkgs = [ "brew" "system" ];
  #   flakes = [ "brew" "system" ];
  # };

  # ========================================
  # Binary Cache Configuration
  # ========================================
  # Configure substituters for flake packages
  # pkgflow.substituters = {
  #   enable = true;
  #   context = "system";  # or "home" or null
  #   onlyTrusted = false;  # Set true for trusted-substituters
  # };

  # Override or add substituter mappings:
  # pkgflow.substituters.mappingOverrides = [
  #   # Override existing default mapping
  #   {
  #     flake = "github:helix-editor/helix";
  #     substituter = "https://my-custom-cache.org";
  #     trustedKey = "my-cache.org-1:customkey==";
  #   }
  #   # Add new mapping for custom flake
  #   {
  #     flake = "github:myorg/myflake";
  #     substituter = "https://myflake.cachix.org";
  #     trustedKey = "myflake.cachix.org-1:key==";
  #   }
  # ];

  # ========================================
  # Homebrew Mapping Configuration
  # ========================================
  # The default mapping is loaded automatically from config/mapping.toml

  # Override or add Homebrew mappings:
  # pkgflow.pkgs.homebrewMappingOverrides = [
  #   # Override existing default mapping
  #   { nix = "git"; brew = "git-custom"; }
  #   # Change neovim from formula to cask
  #   { nix = "neovim"; cask = "neovim"; brew = null; }
  #   # Add new mapping for custom package
  #   { nix = "myapp"; brew = "myapp"; }
  #   { nix = "custom-tool"; cask = "custom-tool"; }
  # ];

  # Final mapping = defaults merged with overrides (overrides take precedence)

  # Rest of your nix-darwin configuration
  system.stateVersion = 6;
}
