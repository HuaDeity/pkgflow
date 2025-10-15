# Home-manager module for installing packages from package manifests
{ config, lib, pkgs, outputTarget ? "auto", ... }:

let
  cfg = config.pkgflow.manifestPackages;

  processManifest = manifestCfg:
    let
      manifestFile = manifestCfg.manifestFile;

      manifest =
        if manifestFile != null then
          lib.importTOML manifestFile
        else
          { };

      packages = manifest.install or { };

      # Simplified system matching logic
      systemMatches = attrs:
        !manifestCfg.requireSystemMatch
        || !(attrs ? systems)
        || lib.elem pkgs.system attrs.systems;

      systemFilteredPackages = lib.filterAttrs (_: systemMatches) packages;

      # Unified package resolution
      resolvePackage = name: attrs:
        if attrs ? flake then
          # Flake package resolution
          lib.attrByPath
            [ name "packages" pkgs.system "default" ]
            null
            (manifestCfg.flakeInputs or {})
        else
          # Regular nixpkgs package resolution
          let
            parts = if builtins.isList attrs.pkg-path
                    then attrs.pkg-path
                    else lib.splitString "." attrs.pkg-path;
          in
          lib.attrByPath parts null pkgs;

      resolvedPackages = lib.filter
        (pkg: pkg != null)
        (lib.mapAttrsToList resolvePackage systemFilteredPackages);
    in
    resolvedPackages;
in
{
  options.pkgflow.manifestPackages = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable automatic package installation from package manifest.";
    };

    manifestFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the manifest TOML file to import.
        When left as null, uses pkgflow.manifest.file if available.
      '';
      example = lib.literalExpression "./my-project/.flox/env/manifest.toml";
    };

    flakeInputs = lib.mkOption {
      type = lib.types.unspecified;
      default = null;
      description = ''
        Flake inputs to use for resolving flake-based packages in the manifest.
        Pass your flake's inputs attribute here to enable flake package resolution.
        Falls back to pkgflow.manifest.flakeInputs if available.
      '';
      example = lib.literalExpression "inputs";
    };

    requireSystemMatch = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Require package entries to list the current system under `systems`.
        When disabled, entries without a systems list are always included.
      '';
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

      # Resolution order for flakeInputs:
      # 1. Module-specific flakeInputs
      # 2. Shared pkgflow.manifest.flakeInputs (if exists)
      # 3. null
      actualFlakeInputs =
        if cfg.flakeInputs != null then
          cfg.flakeInputs
        else if hasSharedOptions && config.pkgflow.manifest.flakeInputs != null then
          config.pkgflow.manifest.flakeInputs
        else
          null;

      manifestCfg = cfg // {
        manifestFile = actualManifestFile;
        flakeInputs = actualFlakeInputs;
      };
    in
    lib.mkMerge [
      # Validation assertions
      {
        assertions = [
          {
            assertion = actualManifestFile != null;
            message = ''
              pkgflow.manifestPackages: No manifest file specified.

              Please set either:
              1. pkgflow.manifestPackages.manifestFile = ./path/to/manifest.toml;
              2. Import sharedModules and set: pkgflow.manifest.file = ./path/to/manifest.toml;
            '';
          }
          {
            assertion = actualManifestFile == null || builtins.pathExists (toString actualManifestFile);
            message = ''
              pkgflow.manifestPackages: Manifest file does not exist:
              ${toString actualManifestFile}

              Check that the path is correct and the file exists.
            '';
          }
        ];
      }

      # Install packages based on outputTarget
      (lib.optionalAttrs (outputTarget == "home") {
        home.packages = processManifest manifestCfg;
      })
      (lib.optionalAttrs (outputTarget == "system") {
        environment.systemPackages = processManifest manifestCfg;
      })
    ]
  );
}
