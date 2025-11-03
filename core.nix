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

  # Process manifest into package list (exported for platform modules to use)
  packagesList = pkgflowLib.processManifest actualManifestFile cfg.requireSystemMatch;

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

    requireSystemMatch = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Control how packages WITHOUT a systems attribute are handled.
        Packages WITH a systems attribute are always filtered by the current system.

        When false (default): Install packages without systems attribute (assume compatible).
        When true: Skip packages without systems attribute (only install explicitly marked packages).
      '';
    };

    # Internal option - computed package list for platform modules to use
    _packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      default = packagesList;
      description = "Computed list of packages from manifest (for internal use by platform modules)";
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
