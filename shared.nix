# Shared configuration for pkgflow manifest-based package management
{ config, lib, ... }:

{
  options.pkgflow = {
    enable = lib.mkEnableOption "pkgflow with smart defaults" // {
      description = ''
        Enable pkgflow with automatic manifest detection and sensible defaults.
        When enabled, automatically searches for manifest files in common locations.
      '';
    };

    manifest = {
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to the package manifest file (e.g., Flox manifest.toml).
          This is the default manifest path used by all pkgflow modules.
        '';
        example = lib.literalExpression "./path/to/manifest.toml";
      };

      flakeInputs = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = ''
          Global flake inputs to use for resolving flake-based packages.
          This can be overridden per-module if needed.
        '';
        example = lib.literalExpression "inputs";
      };
    };
  };

  config = lib.mkIf config.pkgflow.enable {
    pkgflow.manifestPackages = {
      enable = lib.mkDefault true;

      # Auto-detect manifest file in common locations
      manifestFile = lib.mkDefault (
        let
          candidates = [
            ./manifest.toml
            ./.flox/env/manifest.toml
            ~/.config/flox/manifest.toml
          ];
          existingFiles = builtins.filter (f: builtins.pathExists f) candidates;
        in
        if existingFiles != [] then
          builtins.head existingFiles
        else if config.pkgflow.manifest.file != null then
          config.pkgflow.manifest.file
        else
          null
      );

      # Use global flake inputs by default
      flakeInputs = lib.mkDefault config.pkgflow.manifest.flakeInputs;
    };
  };
}
