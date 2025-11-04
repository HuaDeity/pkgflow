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

  # Load and merge all manifest packages (unresolved) already filtered for the current system
  manifestPackages =
    if (builtins.length cfg.manifestFiles) == 1 then
      pkgflowLib.loadManifest (builtins.head cfg.manifestFiles)
    else
      # Load multiple manifests and concatenate them
      lib.concatMap (file: pkgflowLib.loadManifest file) cfg.manifestFiles;

  # Determine platform
  isDarwin = pkgs.stdenv.isDarwin;

  # Determine which packages should be installed based on sources
  shouldInstallNixpkgs =
    if !isDarwin then
      cfg.pkgs.enable # On non-Darwin, respect pkgs.enable option
    else
      cfg.pkgs.enable && (builtins.length cfg.pkgs.nixpkgs) > 0;

  shouldInstallFlakes = cfg.pkgs.enable && (builtins.length cfg.pkgs.flakes) > 0;

  # Check if we want brew (only on Darwin)
  wantsBrewForNixpkgs = isDarwin && builtins.elem "brew" cfg.pkgs.nixpkgs;
  wantsBrewForFlakes = isDarwin && builtins.elem "brew" cfg.pkgs.flakes;
  wantsBrew = wantsBrewForNixpkgs || wantsBrewForFlakes;

  # Load default homebrew mappings
  defaultHomebrewMapping =
    let
      mapping = lib.importTOML ../config/mapping.toml;
    in
    mapping.package;

  # Merge default and override mappings
  # Overrides replace defaults with the same 'nix' field
  finalHomebrewMappingList =
    let
      # Convert lists to attrsets keyed by nix name for easy merging
      defaultAttrs = lib.listToAttrs (
        lib.map (entry: {
          name = entry.nix;
          value = entry;
        }) defaultHomebrewMapping
      );
      overrideAttrs = lib.listToAttrs (
        lib.map (entry: {
          name = entry.nix;
          value = entry;
        }) cfg.pkgs.homebrewMappingOverrides
      );
      # Merge: defaults, then overrides
      merged = defaultAttrs // overrideAttrs;
    in
    lib.attrValues merged;

  # Load homebrew mapping (only if needed)
  homebrewMapping =
    if !wantsBrew then
      { }
    else
      lib.listToAttrs (
        lib.map (entry: {
          name = entry.nix;
          value = entry;
        }) finalHomebrewMappingList
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

  # Load default substituters mappings
  defaultSubstitutersMapping = import ../config/caches.nix;

  # Merge default and override mappings
  # Overrides replace defaults with the same 'flake' field
  finalSubstitutorsMapping =
    let
      # Convert lists to attrsets keyed by flake reference for easy merging
      defaultAttrs = lib.listToAttrs (
        lib.map (entry: {
          name = entry.flake;
          value = entry;
        }) defaultSubstitutersMapping
      );
      overrideAttrs = lib.listToAttrs (
        lib.map (entry: {
          name = entry.flake;
          value = entry;
        }) cfg.substituters.mappingOverrides
      );
      # Merge: defaults, then overrides
      merged = defaultAttrs // overrideAttrs;
    in
    lib.attrValues merged;

  # Compute caches (includes all flakes regardless of installation)
  cacheResult = pkgflowLib.computeCaches {
    flakePackages = processed.flakePackages;
    cacheMapping = finalSubstitutorsMapping;
    addNixCommunity = cfg.substituters.addNixCommunity;
  };
in
{
  options.pkgflow = {
    manifestFiles = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.path;
      apply = map toString;
      description = ''
        List of manifest TOML files to import and merge.
        All manifests are loaded and their packages are combined.
        Must contain at least one file.
      '';
      example = lib.literalExpression ''
        [
          ./project-a/manifest.toml
          ./project-b/manifest.toml
        ]
      '';
    };

    pkgs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable package installation from the manifest.
          When disabled, packages are not installed but substituters can still be configured.
        '';
      };

      nixpkgs = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "system"
            "brew"
            "home"
          ]
        );
        default = [ "home" ];
        description = ''
          On Darwin: List of package installation sources for nixpkgs packages.
          On NixOS: This option is ignored (packages always go to environment.systemPackages).

          Options:
          - "brew": Install via Homebrew (Darwin only, homebrew.brews/casks) - packages split by mapping
          - "system": Install Nix packages via environment.systemPackages
          - "home": Install Nix packages via home.packages

          Note: Cannot use both "system" and "home" together.

          If "brew" is specified, packages are split:
          - Packages that support brew (brew != null/false in mapping) → Homebrew
          - Packages that don't support brew → Nix (via "system" or "home")

          If this list is empty ([]), nixpkgs packages are not installed on Darwin.

          Default: ["home"]
        '';
        example = lib.literalExpression ''[ "brew" "system" ]'';
      };

      flakes = lib.mkOption {
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
          but can still contribute to substituters configuration if substituters.enable = true.

          Default: [] (don't install flake packages)
        '';
        example = lib.literalExpression ''[ "brew" "home" ]'';
      };

      homebrewMappingOverrides = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              nix = lib.mkOption {
                type = lib.types.str;
                description = "Nix package name (from nixpkgs)";
              };
              brew = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "Homebrew formula name (null means not available in Homebrew)";
              };
              cask = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Homebrew cask name (if this is a cask instead of formula)";
              };
            };
          }
        );
        default = [];
        description = ''
          Override or add Homebrew mappings.

          The default mapping is automatically loaded from config/mapping.toml.
          Use this option to:
          - Override specific default entries (by matching 'nix' field)
          - Add new mappings for packages not in the defaults

          Final mapping = defaults merged with overrides (overrides take precedence).
        '';
        example = lib.literalExpression ''
          [
            # Override existing default mapping
            { nix = "git"; brew = "git-custom"; }
            # Change neovim from formula to cask
            { nix = "neovim"; cask = "neovim"; brew = null; }
            # Add new mapping for custom package
            { nix = "myapp"; brew = "myapp"; }
          ]
        '';
      };
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

    substituters = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable binary cache/substituter configuration from flake packages.
          When enabled, configures Nix substituters and trusted public keys
          based on the flake packages in the manifest.

          Works independently of pkgs.enable - you can configure substituters
          without installing flake packages.
        '';
      };

      context = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "home"
            "system"
          ]
        );
        default = "home";
        description = ''
          Where to configure substituters:

          - null: Do nothing, no substituter configuration
          - "home" (default): Configure at home-manager level using:
            - extra-substituters
            - extra-trusted-public-keys
          - "system": Configure at system level (nix-darwin or NixOS) using:
            - substituters
            - trusted-public-keys

          This option is independent of onlyTrusted.

          Default: "home"
        '';
      };

      onlyTrusted = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Standalone option to configure trusted substituters at system level.
          This is useful for non-trusted users who need system-level trust configuration.

          Configuration (when onlyTrusted = true):
          - trusted-substituters (system level)
          - trusted-public-keys (system level)

          This option is independent of context and can be used together with it.

          Default: false
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

      mappingOverrides = lib.mkOption {
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
        default = [];
        description = ''
          Override or add substituter/cache mappings for flake packages.

          The default mapping is automatically loaded from config/caches.nix.
          Use this option to:
          - Override specific default entries (by matching 'flake' field)
          - Add new mappings for flakes not in the defaults

          Final mapping = defaults merged with overrides (overrides take precedence).
        '';
        example = lib.literalExpression ''
          [
            # Override existing default mapping
            {
              flake = "github:helix-editor/helix";
              substituter = "https://my-custom-cache.org";
              trustedKey = "my-cache.org-1:customkey==";
            }
            # Add new mapping for custom flake
            {
              flake = "github:myorg/myflake";
              substituter = "https://myflake.cachix.org";
              trustedKey = "myflake.cachix.org-1:key==";
            }
          ]
        '';
      };
    };
  };

  config = lib.mkMerge [
    # Validation assertions
    {
      assertions = [
        {
          assertion = builtins.all (file: builtins.pathExists (toString file)) cfg.manifestFiles;
          message =
            let
              missingFiles = builtins.filter (file: !builtins.pathExists (toString file)) cfg.manifestFiles;
              fileList = lib.concatMapStringsSep "\n  - " toString missingFiles;
            in
            ''
              pkgflow: Some manifest files do not exist:
                ${fileList}

              Check that the paths are correct and the files exist.
            '';
        }
        {
          assertion =
            !(builtins.elem "system" cfg.pkgs.nixpkgs && builtins.elem "home" cfg.pkgs.nixpkgs);
          message = ''
            pkgflow: Cannot use both "system" and "home" in pkgs.nixpkgs.

            Choose one:
            - Use "system" to install via environment.systemPackages
            - Use "home" to install via home.packages

            You can combine either with "brew".
          '';
        }
        {
          assertion =
            !(builtins.elem "system" cfg.pkgs.flakes && builtins.elem "home" cfg.pkgs.flakes);
          message = ''
            pkgflow: Cannot use both "system" and "home" in pkgs.flakes.

            Choose one:
            - Use "system" to install via environment.systemPackages
            - Use "home" to install via home.packages

            You can combine either with "brew".
          '';
        }
      ];
    }
  ];
}
