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

      systemMatches =
        attrs:
        let
          hasSystems = attrs ? systems;
        in
        if manifestCfg.requireSystemMatch then
          hasSystems && lib.elem pkgs.system attrs.systems
        else
          (!hasSystems) || lib.elem pkgs.system attrs.systems;

      systemFilteredPackages = lib.filterAttrs (_: attrs: systemMatches attrs) packages;

      getPackage =
        pkgPath:
        let
          parts =
            if builtins.isList pkgPath then
              pkgPath
            else
              lib.splitString "." pkgPath;
        in
        lib.attrByPath parts null pkgs;

      regularPackages = lib.filterAttrs (_: attrs: !(attrs ? flake)) systemFilteredPackages;
      regularList = lib.filter (pkg: pkg != null) (
        lib.mapAttrsToList (_: attrs: getPackage attrs.pkg-path) regularPackages
      );

      # Note: Flake packages require access to flake inputs
      # Users need to pass flake inputs to resolve these
      flakePackages = lib.filterAttrs (_: attrs: attrs ? flake) systemFilteredPackages;

      resolveFlakePackage =
        name:
        if manifestCfg.flakeInputs != null then
          lib.attrByPath
            [ name "packages" pkgs.system "default" ]
            null
            manifestCfg.flakeInputs
        else
          null;

      flakeList = lib.mapAttrsToList (name: _: resolveFlakePackage name) flakePackages;

      resolvedPackages =
        regularList
        ++ lib.filter (pkg: pkg != null) flakeList;
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
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = ''
        Flake inputs to use for resolving flake-based packages in the manifest.
        Pass your flake's inputs attribute here to enable flake package resolution.
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
