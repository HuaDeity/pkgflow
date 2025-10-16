# Darwin/macOS module for converting package manifests to Homebrew packages
{ config, lib, pkgs, ... }:

let
  cfg = config.pkgflow.homebrewManifest;

  defaultMappingFile = ./config/mapping.toml;
in
{
  options.pkgflow.homebrewManifest = {
    manifestFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the package manifest that describes desired packages.
        When left as null, uses pkgflow.manifest.file if available.
      '';
    };

    mappingFile = lib.mkOption {
      type = lib.types.path;
      default = defaultMappingFile;
      description = "Path to the TOML mapping between nix package names and Homebrew formulae.";
    };
  };

  config = let
    # Check if shared options exist
    hasSharedOptions = config.pkgflow ? manifest;

    # Resolution order:
    # 1. Module-specific manifestFile
    # 2. Shared pkgflow.manifest.file (if exists)
    # 3. null
    actualManifestFile =
      if cfg.manifestFile != null then
        cfg.manifestFile
      else if hasSharedOptions && config.pkgflow.manifest.file != null then
        config.pkgflow.manifest.file
      else
        null;

    manifest =
      if actualManifestFile != null then
        lib.importTOML actualManifestFile
      else
        { };

    mapping = lib.importTOML cfg.mappingFile;

    originalPackages = manifest.install or { };

    # Filter: Only packages WITHOUT systems attribute go to Homebrew
    # This prevents duplicate installation (Nix + Homebrew)
    packages = lib.filterAttrs (_: attrs: !(attrs ? systems)) originalPackages;

    # Build Nix → Homebrew lookup table
    nixToBrew = lib.listToAttrs (
      lib.map (entry: {
        name = entry.nix;
        value = entry;
      }) mapping.package
    );

    # Convert package to Homebrew format
    convertToBrew = _: attrs:
      let
        # Normalize package path for lookup
        lookupKey = attrs.flake or (
          if builtins.isList attrs.pkg-path
          then builtins.concatStringsSep "." attrs.pkg-path
          else attrs.pkg-path
        );

        # Get mapping or use package name as fallback
        brewInfo = nixToBrew.${lookupKey} or {
          brew = lookupKey;
          type = "formula";
        };
      in
      brewInfo;

    converted = lib.mapAttrsToList convertToBrew packages;

    # Split into formulas and casks
    formulas = lib.filter (p: (p.type or "formula") == "formula") converted;
    casks = lib.filter (p: (p.type or "") == "cask") converted;

    # Format brew entries (handle args)
    formatBrew = p:
      if p ? args then
        { name = p.brew; args = p.args; }
      else
        p.brew;
  in
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = pkgs.stdenv.isDarwin;
            message = ''
              pkgflow.homebrewManifest: This module is only for macOS/Darwin.

              The Homebrew module (brewModules.default) can only be used on macOS.
              For other platforms, use nixModules.default instead.
            '';
          }
          {
            assertion = actualManifestFile != null;
            message = ''
              pkgflow.homebrewManifest: No manifest file specified.

              Please set either:
              1. pkgflow.homebrewManifest.manifestFile = ./path/to/manifest.toml;
              2. Import sharedModules and set: pkgflow.manifest.file = ./path/to/manifest.toml;
            '';
          }
          {
            assertion = actualManifestFile == null || builtins.pathExists (toString actualManifestFile);
            message = ''
              pkgflow.homebrewManifest: Manifest file does not exist:
              ${toString actualManifestFile}

              Check that the path is correct and the file exists.
            '';
          }
          {
            assertion = builtins.pathExists (toString cfg.mappingFile);
            message = ''
              pkgflow.homebrewManifest: Mapping file does not exist:
              ${toString cfg.mappingFile}

              Check that the path is correct and the file exists.
            '';
          }
        ];
      }
      {
        homebrew.brews = lib.map formatBrew formulas;
        homebrew.casks = lib.map (p: p.brew) casks;
      }
    ];
}
