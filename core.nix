# Core pkgflow module - shared options and logic
# Platform-specific modules import this and add package installation
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Import pkgflow lib functions
  pkgflowLib = import ./lib {
    inherit lib pkgs inputs;
  };

  cfg = config.pkgflow;

  # Check if shared options exist
  hasSharedOptions = config.pkgflow ? manifest;

  # Resolution order:
  # 1. Module-specific manifestFile
  # 2. Shared pkgflow.manifest.file (if exists)
  # 3. null
  actualManifestFile =
    if cfg.manifestFile != null then
      cfg.manifestFile
    else if hasSharedOptions && cfg.manifest.file != null then
      cfg.manifest.file
    else
      null;

  # Load manifest and get all packages (unresolved, just the attrset from manifest)
  manifestPackages =
    if actualManifestFile != null then
      let
        manifest = lib.importTOML actualManifestFile;
      in
      manifest.install or { }
    else
      { };

  # On Darwin with darwinPackagesSource: filter packages by installation source
  # Otherwise: install all packages via the default method
  isDarwin = pkgs.stdenv.isDarwin;
  hasDarwinSources = isDarwin && (builtins.length cfg.darwinPackagesSource) > 0;

  # Load homebrew mapping if needed
  homebrewMapping =
    if hasDarwinSources && builtins.elem "brew" cfg.darwinPackagesSource then
      let
        mapping = lib.importTOML cfg.homebrewMappingFile;
      in
      lib.listToAttrs (
        lib.map (entry: {
          name = entry.nix;
          value = entry;
        }) mapping.package
      )
    else
      { };

  # Check if a package can be installed via Homebrew
  canInstallViaBrew =
    name: attrs:
    let
      # Normalize package path for lookup
      lookupKey =
        attrs.flake or (
          if builtins.isList attrs.pkg-path then
            builtins.concatStringsSep "." attrs.pkg-path
          else
            attrs.pkg-path
        );
      brewInfo = homebrewMapping.${lookupKey} or null;
    in
    brewInfo != null && (brewInfo.brew or null) != null && (brewInfo.brew or null) != false;

  # Filter packages by installation source (for Darwin only)
  packagesBySource =
    if !hasDarwinSources then
      {
        all = manifestPackages;
        brew = { };
        system = { };
        home = { };
      }
    else
      let
        wantsBrew = builtins.elem "brew" cfg.darwinPackagesSource;
        wantsSystem = builtins.elem "system" cfg.darwinPackagesSource;
        wantsHome = builtins.elem "home" cfg.darwinPackagesSource;

        # Categorize each package
        categorize =
          name: attrs:
          if wantsBrew && canInstallViaBrew name attrs then
            "brew"
          else if wantsSystem then
            "system"
          else if wantsHome then
            "home"
          else
            null;

        categorized = lib.mapAttrs categorize manifestPackages;

        filterByCategory =
          category: lib.filterAttrs (name: _: (categorized.${name} or null) == category) manifestPackages;
      in
      {
        all = { };
        brew = filterByCategory "brew";
        system = filterByCategory "system";
        home = filterByCategory "home";
      };

  # Resolve packages for each category
  resolvedPackages = {
    all = pkgflowLib.processManifestPackages packagesBySource.all;
    brew = packagesBySource.brew; # Keep unresolved for homebrew conversion
    system = pkgflowLib.processManifestPackages packagesBySource.system;
    home = pkgflowLib.processManifestPackages packagesBySource.home;
  };

  # Compute caches
  cacheResult = pkgflowLib.computeCaches {
    manifestFile = actualManifestFile;
    cacheMapping = cfg.caches.mapping;
    addNixCommunity = cfg.caches.addNixCommunity;
  };
in
{
  options.pkgflow = {
    manifestFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      apply = x: if x != null then toString x else null;
      description = ''
        Path to the manifest TOML file to import.
        When left as null, uses pkgflow.manifest.file if available.
      '';
      example = lib.literalExpression "./my-project/.flox/env/manifest.toml";
    };

    # Darwin-specific: choose where to install packages
    darwinPackagesSource = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "system" "brew" "home" ]);
      default = [ ];
      description = ''
        On Darwin only: List of package installation sources in priority order.

        - "brew": Install via Homebrew (homebrew.brews/casks)
        - "system": Install via Nix system packages (environment.systemPackages)
        - "home": Install via home-manager (home.packages)

        Packages are installed using the first matching source:
        1. If "brew" is in the list and package supports Homebrew: install via brew
        2. Otherwise if "system" is in the list: install via systemPackages
        3. Otherwise if "home" is in the list: install via home.packages

        If a package cannot be installed via brew (brew = null/false in mapping),
        it falls back to the next available source.

        If this list is empty (default), all packages are installed via the
        platform module's default method.
      '';
      example = lib.literalExpression ''[ "brew" "system" ]'';
    };

    homebrewMappingFile = lib.mkOption {
      type = lib.types.path;
      default = ./config/mapping.toml;
      apply = toString;
      description = ''
        Path to the TOML mapping between nix package names and Homebrew formulae.
        Used when darwinPackagesSource includes "brew".
      '';
    };

    # Internal options - computed package lists for platform modules to use
    _packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      default = resolvedPackages.all;
      description = "All packages (when not using darwinPackagesSource filtering)";
    };

    _systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      default = resolvedPackages.system;
      description = "Packages to install via environment.systemPackages";
    };

    _homePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      default = resolvedPackages.home;
      description = "Packages to install via home.packages";
    };

    _brewPackages = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      internal = true;
      readOnly = true;
      default = resolvedPackages.brew;
      description = "Unresolved packages to install via Homebrew";
    };

    caches = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable binary cache configuration from flake packages.
          When enabled, sets nix.settings.substituters and nix.settings.trusted-public-keys
          based on the flake packages in the manifest.
        '';
      };

      onlyTrusted = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Only set trusted-substituters and trusted-public-keys (system level only).
          Useful when you want to configure trust at system level but let home-manager handle substituters.

          This is useful for non-trusted users who need system-level trust configuration.
        '';
      };

      addNixCommunity = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Control nix-community.cachix.org cache for github:nix-community/* flakes.

          Behavior:
          - null (default): Auto-detect - add cache only if nix-community flakes are found
          - true: Always add nix-community cache, regardless of whether flakes are detected
          - false: Never add nix-community cache, even if nix-community flakes exist
        '';
      };

      mapping = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              flake = lib.mkOption {
                type = lib.types.str;
                description = "Flake reference (e.g., github:helix-editor/helix)";
              };
              substituter = lib.mkOption {
                type = lib.types.str;
                description = "Binary cache URL";
              };
              trustedKey = lib.mkOption {
                type = lib.types.str;
                description = "Public key for the binary cache";
              };
            };
          }
        );
        default = import ./config/caches.nix;
        description = ''
          Mapping of flake references to binary caches and trusted keys.
        '';
      };
    };
  };

  config = lib.mkMerge [
    # Validation assertions
    {
      assertions = [
        {
          assertion = actualManifestFile != null;
          message = ''
            pkgflow: No manifest file specified.

            Please set either:
            1. pkgflow.manifestFile = ./path/to/manifest.toml;
            2. Import sharedModules and set: pkgflow.manifest.file = ./path/to/manifest.toml;
          '';
        }
        {
          assertion = actualManifestFile == null || builtins.pathExists (toString actualManifestFile);
          message = ''
            pkgflow: Manifest file does not exist:
            ${toString actualManifestFile}

            Check that the path is correct and the file exists.
          '';
        }
        {
          assertion =
            actualManifestFile == null
            || !hasDarwinSources
            || builtins.pathExists (toString cfg.homebrewMappingFile);
          message = ''
            pkgflow: Homebrew mapping file does not exist:
            ${toString cfg.homebrewMappingFile}

            Check that the path is correct and the file exists.
          '';
        }
      ];
    }

    # Binary cache configuration
    (lib.mkIf (cfg.caches.enable && cacheResult.hasMatches) {
      nix.settings =
        if cfg.caches.onlyTrusted then
          {
            trusted-substituters = cacheResult.substituters;
            trusted-public-keys = cacheResult.trustedKeys;
          }
        else
          {
            substituters = cacheResult.substituters;
            trusted-public-keys = cacheResult.trustedKeys;
          };
    })
  ];
}
