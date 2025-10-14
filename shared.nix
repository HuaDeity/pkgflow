# Shared configuration for Flox manifest-based package management
{ lib, ... }:

{
  options.flox.manifest = {
    file = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the Flox manifest.toml file.
        This is the default manifest path used by all Flox manifest modules.
      '';
      example = lib.literalExpression "./path/to/manifest.toml";
    };
  };
}
