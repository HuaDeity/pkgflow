# Darwin/macOS module for converting Flox manifest to Homebrew packages
{ config, lib, ... }:

let
  cfg = config.flox.homebrewManifest;

  defaultMappingFile = ./config/mapping.toml;
in
{
  options.flox.homebrewManifest = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable automatic Homebrew package installation from Flox manifest.";
    };

    manifestFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the Flox-style manifest that describes desired packages.
        When left as null, uses flox.manifest.file if available.
      '';
    };

    mappingFile = lib.mkOption {
      type = lib.types.path;
      default = defaultMappingFile;
      description = "Path to the TOML mapping between nix package names and Homebrew formulae.";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      # Use manifestFile if set, otherwise fall back to flox.manifest.file
      actualManifestFile =
        if cfg.manifestFile != null then
          cfg.manifestFile
        else
          config.flox.manifest.file or null;

      manifest =
        if actualManifestFile != null then
          lib.importTOML actualManifestFile
        else
          { };

      mapping = lib.importTOML cfg.mappingFile;

      originalPackages = manifest.install or { };

      packages = lib.filterAttrs (name: attrs: !(attrs ? systems)) originalPackages;

      normalizePath =
        pkgPath:
        if builtins.isList pkgPath then
          builtins.concatStringsSep "." pkgPath
        else
          pkgPath;

      nixToBrew = lib.listToAttrs (
        lib.map (entry: {
          name = entry.nix;
          value = entry;
        }) mapping.package
      );

      converted = lib.mapAttrsToList (
        _: attrs:
        let
          lookupKey = attrs.flake or (normalizePath attrs.pkg-path);
          brewInfo =
            nixToBrew.${lookupKey} or {
              brew = lookupKey;
              type = "formula";
            };
        in
        brewInfo
      ) packages;

      formatBrew =
        p:
        if p ? args then
          {
            name = p.brew;
            args = p.args;
          }
        else
          p.brew;
    in
    {
      homebrew.brews = lib.map formatBrew (lib.filter (p: (p.type or "formula") == "formula") converted);
      homebrew.casks = lib.map (p: p.brew) (lib.filter (p: p ? type && p.type == "cask") converted);
    }
  );
}
