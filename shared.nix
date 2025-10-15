# Shared configuration for pkgflow manifest-based package management
{ lib, ... }:

{
  options.pkgflow.manifest = {
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
}
