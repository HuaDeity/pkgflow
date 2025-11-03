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

  hasDarwinSources = pkgs.stdenv.isDarwin && (builtins.length cfg.darwinPackagesSource) > 0;
  wantsSystem = hasDarwinSources && builtins.elem "system" cfg.darwinPackagesSource;
  wantsBrew = hasDarwinSources && builtins.elem "brew" cfg.darwinPackagesSource;

  # Convert brew packages attrset to homebrew format
  homebrewMapping = lib.importTOML cfg.homebrewMappingFile;
  nixToBrew = lib.listToAttrs (
    lib.map (entry: {
      name = entry.nix;
      value = entry;
    }) homebrewMapping.package
  );

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

  converted = lib.mapAttrsToList convertToBrew cfg._brewPackages;
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
{
  imports = [
    coreModule
  ];

  config =
    let
      manifestFile = if cfg.manifestFile != null then cfg.manifestFile else (cfg.manifest.file or null);
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
        ];
      }

      # Default behavior (no darwinPackagesSource): install all via systemPackages
      (lib.mkIf (!hasDarwinSources && manifestFile != null) {
        environment.systemPackages = cfg._packages;
      })

      # Install via systemPackages (when "system" in darwinPackagesSource)
      (lib.mkIf wantsSystem {
        environment.systemPackages = cfg._systemPackages;
      })

      # Install via Homebrew (when "brew" in darwinPackagesSource)
      (lib.mkIf wantsBrew {
        homebrew.brews = lib.map formatBrew formulas;
        homebrew.casks = lib.map (p: p.brew) casks;
      })
    ];
}
