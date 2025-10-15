# Example: nix-darwin configuration
#
# This example shows recommended patterns for using pkgflow on macOS
# with nix-darwin to manage packages via Nix and/or Homebrew.

{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.pkgflow.darwinModules.default
  ];

  # Global configuration
  pkgflow.manifest = {
    file = ~/.config/flox/manifest.toml;
    flakeInputs = inputs;
  };

  # ========================================
  # RECOMMENDED: Strategy 1 - Homebrew-First
  # ========================================
  # Use Homebrew for most packages, Nix only for packages unavailable in Homebrew
  #
  # In your manifest.toml:
  # - Packages WITHOUT 'systems' → Installed via Homebrew
  # - Packages WITH 'systems' → Installed via Nix
  #
  # Example manifest.toml:
  #   [install]
  #   git.pkg-path = "git"                    # → Homebrew
  #   neovim.pkg-path = "neovim"              # → Homebrew
  #
  #   nixfmt.pkg-path = "nixfmt-rfc-style"    # → Nix
  #   nixfmt.systems = ["aarch64-darwin"]
  #
  #   helix.flake = "github:helix-editor/helix"  # → Nix
  #   helix.systems = ["aarch64-darwin"]

  pkgflow.homebrewManifest.enable = true;

  pkgflow.manifestPackages = {
    enable = true;
    requireSystemMatch = true;  # IMPORTANT: Only install if systems explicitly matches
    output = "system";
  };

  # ========================================
  # Alternative: Strategy 2 - Nix-Only
  # ========================================
  # Use Nix for everything (same as Linux/NixOS behavior)
  #
  # Uncomment below and comment out Strategy 1:

  # pkgflow.manifestPackages = {
  #   enable = true;
  #   output = "system";
  #   # requireSystemMatch = false (default) - installs all packages via Nix
  # };

  # ========================================
  # Advanced: Custom Homebrew Mapping
  # ========================================
  # Use a custom Nix → Homebrew mapping file

  # pkgflow.homebrewManifest = {
  #   enable = true;
  #   mappingFile = ./my-custom-mapping.toml;
  # };

  # Rest of your nix-darwin configuration
  system.stateVersion = 6;
}
