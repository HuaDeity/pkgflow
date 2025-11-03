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
  pkgflowLib = import ../lib {
    inherit lib pkgs inputs;
  };

  cfg = config.pkgflow;

  # Load manifest packages (unresolved) already filtered for the current system
  manifestPackages = pkgflowLib.loadManifest cfg.manifestFile;

  # Determine platform
  isDarwin = pkgs.stdenv.isDarwin;

  # Determine which packages should be installed based on sources
  shouldInstallNixpkgs =
    if !isDarwin then
      true # On non-Darwin, nixpkgs packages are always installed (via platform module)
    else
      (builtins.length cfg.darwinPackagesSource) > 0;

  shouldInstallFlakes = (builtins.length cfg.flakePackagesSource) > 0;

  # Check if we want brew (only on Darwin)
  wantsBrewForNixpkgs = isDarwin && builtins.elem "brew" cfg.darwinPackagesSource;
  wantsBrewForFlakes = isDarwin && builtins.elem "brew" cfg.flakePackagesSource;
  wantsBrew = wantsBrewForNixpkgs || wantsBrewForFlakes;

  # Load homebrew mapping (only if needed)
  homebrewMapping =
    if !wantsBrew then
      { }
    else
      let
        mapping = lib.importTOML cfg.homebrewMappingFile;
      in
      lib.listToAttrs (
        lib.map (entry: {
          name = entry.nix;
          value = entry;
        }) mapping.package
      );

  # Process entire manifest in one pass - returns all outputs we need
  processed = pkgflowLib.processManifest {
    inherit
      manifestPackages
      shouldInstallNixpkgs
      shouldInstallFlakes
      wantsBrewForNixpkgs
      wantsBrewForFlakes
      homebrewMapping
      ;
  };

  # Compute caches (includes all flakes regardless of installation)
  cacheResult = pkgflowLib.computeCaches {
    flakePackages = processed.flakePackages;
    cacheMapping = cfg.caches.mapping;
    addNixCommunity = cfg.caches.addNixCommunity;
  };

  # Auto-detect installContext if not explicitly set
  effectiveInstallContext =
    if cfg.caches.installContext != null then
      cfg.caches.installContext
    else
    # Auto-detect from sources
    if
      builtins.elem "system" cfg.darwinPackagesSource || builtins.elem "system" cfg.flakePackagesSource
    then
      "system"
    else if
      builtins.elem "home" cfg.darwinPackagesSource || builtins.elem "home" cfg.flakePackagesSource
    then
      "home"
    else
      "home"; # Default fallback
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

    # Darwin-specific: choose where to install nixpkgs packages
    darwinPackagesSource = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "system"
          "brew"
          "home"
        ]
      );
      default = [
        "brew"
        "home"
      ];
      description = ''
        On Darwin only: List of package installation sources for nixpkgs packages.

        Options:
        - "brew": Install via Homebrew (homebrew.brews/casks) - packages split by mapping
        - "system": Install Nix packages via environment.systemPackages
        - "home": Install Nix packages via home.packages

        Note: Cannot use both "system" and "home" together.

        If "brew" is specified, packages are split:
        - Packages that support brew (brew != null/false in mapping) → Homebrew
        - Packages that don't support brew → Nix (via "system" or "home")

        If this list is empty ([]), nixpkgs packages are not installed on Darwin.

        Default: ["brew" "home"]
      '';
      example = lib.literalExpression ''[ "brew" "system" ]'';
    };

    # All systems: choose where to install flake packages
    flakePackagesSource = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "system"
          "brew"
          "home"
        ]
      );
      default = [ ];
      description = ''
        List of package installation sources for flake packages.

        Options:
        - "brew": Install via Homebrew (Darwin only) - packages split by mapping
        - "system": Install Nix packages via environment.systemPackages
        - "home": Install Nix packages via home.packages

        Note: Cannot use both "system" and "home" together.

        If "brew" is specified on Darwin, packages are split:
        - Flakes that have brew mapping → Homebrew
        - Flakes without brew mapping → Nix (via "system" or "home" from this list)

        If this list is empty (default), flake packages are not installed,
        but can still contribute to binary cache configuration if caches.enable = true.

        Default: [] (don't install flake packages)
      '';
      example = lib.literalExpression ''[ "brew" "home" ]'';
    };

    homebrewMappingFile = lib.mkOption {
      type = lib.types.path;
      default = ../config/mapping.toml;
      apply = toString;
      description = ''
        Path to the TOML mapping between nix package names and Homebrew formulae.
        Used when darwinPackagesSource or flakePackagesSource includes "brew".
      '';
    };

    # Internal options - computed package lists for platform modules to use
    _nixPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      default = processed.nixPackages;
      description = "Resolved Nix packages to install (both nixpkgs and flake packages combined)";
    };

    _homebrewFormulas = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      internal = true;
      readOnly = true;
      default = processed.homebrewFormulas;
      description = "Homebrew formulas to install (pre-converted)";
    };

    _homebrewCasks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
      default = processed.homebrewCasks;
      description = "Homebrew casks to install (pre-converted)";
    };

    _cacheResult = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      readOnly = true;
      default = cacheResult;
      description = "Computed cache result (shared between modules to avoid duplication)";
    };

    _effectiveInstallContext = lib.mkOption {
      type = lib.types.enum [
        "system"
        "home"
      ];
      internal = true;
      readOnly = true;
      default = effectiveInstallContext;
      description = "Effective install context after auto-detection (shared between modules)";
    };

    caches = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable binary cache configuration from flake packages.
          When enabled, sets nix.settings.substituters and nix.settings.trusted-public-keys
          based on the flake packages in the manifest.

          Works independently of flakePackagesSource - you can configure caches
          without installing flake packages.
        '';
      };

      installContext = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "system"
            "home"
          ]
        );
        default = null;
        description = ''
          Where to install binary cache configuration.

          Options:
          - "system": Configure at system level (nix-darwin or NixOS)
          - "home": Configure at home-manager level
          - null (default): Auto-detect from darwinPackagesSource and flakePackagesSource

          Auto-detection logic when null:
          - If "system" is in darwinPackagesSource or flakePackagesSource → use "system"
          - Else if "home" is in darwinPackagesSource or flakePackagesSource → use "home"
          - Otherwise → default to "home"

          This is independent of package installation - it controls where
          substituters and trusted-public-keys are configured.

          Default: null (auto-detect)
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
        default = import ../config/caches.nix;
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
          assertion = cfg.manifestFile != null;
          message = ''
            pkgflow: No manifest file specified.

            Please set "pkgflow.manifestFile = ./path/to/manifest.toml";
          '';
        }
        {
          assertion = cfg.manifestFile == null || builtins.pathExists (toString cfg.manifestFile);
          message = ''
            pkgflow: Manifest file does not exist:
            ${toString cfg.manifestFile}

            Check that the path is correct and the file exists.
          '';
        }
        {
          assertion =
            cfg.manifestFile == null || !wantsBrew || builtins.pathExists (toString cfg.homebrewMappingFile);
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
        {
          assertion =
            !(builtins.elem "system" cfg.flakePackagesSource && builtins.elem "home" cfg.flakePackagesSource);
          message = ''
            pkgflow: Cannot use both "system" and "home" in flakePackagesSource.

            Choose one:
            - Use "system" to install via environment.systemPackages
            - Use "home" to install via home.packages

            You can combine either with "brew".
          '';
        }
      ];
    }

    # Binary cache configuration - system level
    (lib.mkIf (cfg.caches.enable && cacheResult.hasMatches && effectiveInstallContext == "system") {
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
