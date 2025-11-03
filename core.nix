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

  # Determine platform and settings
  isDarwin = pkgs.stdenv.isDarwin;
  wantsBrew = isDarwin && builtins.elem "brew" cfg.darwinPackagesSource;

  # Split packages into nix and brew categories
  packageSplit =
    if !wantsBrew then
      # Not using brew: everything goes to nix
      {
        nix = manifestPackages;
        brew = { };
      }
    else
      # Using brew: filter by mapping
      let
        # Load homebrew mapping
        mapping = lib.importTOML cfg.homebrewMappingFile;
        homebrewMapping = lib.listToAttrs (
          lib.map (entry: {
            name = entry.nix;
            value = entry;
          }) mapping.package
        );

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
            brewVal = if brewInfo ? brew then brewInfo.brew else true;
          in
          brewVal != false && brewVal != null;

        # Filter packages
        brewPackages = lib.filterAttrs canInstallViaBrew manifestPackages;
        nixPackages = lib.filterAttrs (
          name: _: !canInstallViaBrew name manifestPackages.${name}
        ) manifestPackages;
      in
      {
        nix = nixPackages;
        brew = brewPackages;
      };

  # Resolve nix packages (brew packages stay unresolved for homebrew module)
  nixPackagesList = pkgflowLib.processManifestPackages packageSplit.nix;

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
      type = lib.types.listOf (
        lib.types.enum [
          "system"
          "brew"
          "home"
        ]
      );
      default = [ ];
      description = ''
        On Darwin only: List of package installation sources.

        Options:
        - "brew": Install via Homebrew (homebrew.brews/casks) - packages split by mapping
        - "system": Install Nix packages via environment.systemPackages
        - "home": Install Nix packages via home.packages

        Note: Cannot use both "system" and "home" together.

        If "brew" is specified, packages are split:
        - Packages that support brew (brew != null/false in mapping) → Homebrew
        - Packages that don't support brew → Nix (via "system" or "home")

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
    _nixPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      default = nixPackagesList;
      description = "Resolved Nix packages to install";
    };

    _brewPackages = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      internal = true;
      readOnly = true;
      default = packageSplit.brew;
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
            actualManifestFile == null || !wantsBrew || builtins.pathExists (toString cfg.homebrewMappingFile);
          message = ''
            pkgflow: Homebrew mapping file does not exist:
            ${toString cfg.homebrewMappingFile}

            Check that the path is correct and the file exists.
          '';
        }
        {
          assertion =
            !(builtins.elem "system" cfg.darwinPackagesSource && builtins.elem "home" cfg.darwinPackagesSource);
          message = ''
            pkgflow: Cannot use both "system" and "home" in darwinPackagesSource.

            Choose one:
            - Use "system" to install via environment.systemPackages
            - Use "home" to install via home.packages

            You can combine either with "brew".
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
