# nix-darwin module for pkgflow
# Provides: environment.systemPackages (or homebrew.brews/casks)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.pkgflow;
  coreModule = import ../core.nix;
in
{
  imports = [
    coreModule
  ];

  options.pkgflow.useHomebrew = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Use Homebrew for package installation instead of Nix systemPackages.

      When true: Install packages via homebrew.brews and homebrew.casks
      When false: Install packages via environment.systemPackages

      Note: Only packages WITHOUT a systems attribute will be converted to Homebrew.
      Packages WITH a systems attribute are always installed via Nix.
    '';
  };

  options.pkgflow.homebrewMappingFile = lib.mkOption {
    type = lib.types.path;
    default = ../config/mapping.toml;
    apply = toString;
    description = "Path to the TOML mapping between nix package names and Homebrew formulae.";
  };

  config =
    let
      manifestFile = if cfg.manifestFile != null then cfg.manifestFile else (cfg.manifest.file or null);

      # Homebrew conversion logic (only when useHomebrew is true)
      manifest = if manifestFile != null then lib.importTOML manifestFile else { };
      homebrewMapping = lib.importTOML cfg.homebrewMappingFile;
      originalPackages = manifest.install or { };

      # Filter: Only packages WITHOUT systems attribute go to Homebrew
      homebrewPackages = lib.filterAttrs (_: attrs: !(attrs ? systems)) originalPackages;

      # Build Nix → Homebrew lookup table
      nixToBrew = lib.listToAttrs (
        lib.map (entry: {
          name = entry.nix;
          value = entry;
        }) homebrewMapping.package
      );

      # Convert package to Homebrew format
      convertToBrew =
        _: attrs:
        let
          lookupKey =
            attrs.flake or (
              if builtins.isList attrs.pkg-path then
                builtins.concatStringsSep "." attrs.pkg-path
              else
                attrs.pkg-path
            );
          brewInfo =
            nixToBrew.${lookupKey} or {
              brew = lookupKey;
              type = "formula";
            };
        in
        brewInfo;

      converted = lib.mapAttrsToList convertToBrew homebrewPackages;
      formulas = lib.filter (p: (p.type or "formula") == "formula") converted;
      casks = lib.filter (p: (p.type or "") == "cask") converted;

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
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = pkgs.stdenv.isDarwin;
            message = ''
              pkgflow (darwin module): This module is only for macOS/Darwin.
              For other platforms, use nixosModules.default instead.
            '';
          }
          {
            assertion =
              manifestFile == null || builtins.pathExists (toString cfg.homebrewMappingFile);
            message = ''
              pkgflow: Homebrew mapping file does not exist:
              ${toString cfg.homebrewMappingFile}

              Check that the path is correct and the file exists.
            '';
          }
        ];
      }

      # Install via systemPackages (when not using homebrew)
      (lib.mkIf (!cfg.useHomebrew && manifestFile != null) {
        environment.systemPackages = cfg._packages;
      })

      # Install via Homebrew (when using homebrew)
      (lib.mkIf (cfg.useHomebrew && manifestFile != null) {
        homebrew.brews = lib.map formatBrew formulas;
        homebrew.casks = lib.map (p: p.brew) casks;
      })
    ];
}
