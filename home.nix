# Home-manager module for installing packages from package manifests
{ config, lib, pkgs, options, ... }:

let
  cfg = config.pkgflow.manifestPackages;

  # Check if we're in a system context (NixOS/Darwin) or home-manager context
  hasSystemPackages = options ? environment.systemPackages;

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
      default = config.pkgflow.manifest.flakeInputs or null;
      description = ''
        Flake inputs to use for resolving flake-based packages in the manifest.
        Pass your flake's inputs attribute here to enable flake package resolution.
        Falls back to pkgflow.manifest.flakeInputs if not set.
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

    output = lib.mkOption {
      type = lib.types.enum [ "home" "system" ];
      default = "home";
      description = ''
        Where to install packages:
        - "home": Install to home.packages (home-manager)
        - "system": Install to environment.systemPackages (NixOS/Darwin system config)
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    let
      # Use manifestFile if set, otherwise fall back to pkgflow.manifest.file
      actualManifestFile =
        if cfg.manifestFile != null then
          cfg.manifestFile
        else
          config.pkgflow.manifest.file or null;

      manifestCfg = cfg // { manifestFile = actualManifestFile; };
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
              - pkgflow.manifestPackages.manifestFile, or
              - pkgflow.manifest.file
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

      # Install packages
      (lib.mkIf (cfg.output == "home") {
        home.packages = processManifest manifestCfg;
      })
      (lib.optionalAttrs hasSystemPackages (
        lib.mkIf (cfg.output == "system") {
          environment.systemPackages = processManifest manifestCfg;
        }
      ))
    ]
  );
}
