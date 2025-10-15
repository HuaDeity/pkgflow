# Darwin/macOS module for converting package manifests to Homebrew packages
{ config, lib, ... }:

let
  cfg = config.pkgflow.homebrewManifest;

  defaultMappingFile = ./config/mapping.toml;
in
{
  options.pkgflow.homebrewManifest = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable automatic Homebrew package installation from package manifest.";
    };

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

  config = lib.mkIf cfg.enable (
    let
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
    {
      homebrew.brews = lib.map formatBrew formulas;
      homebrew.casks = lib.map (p: p.brew) casks;
    }
  );
}
