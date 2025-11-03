# Unified module for installing packages from package manifests
# Auto-detects home-manager vs system context
{
  config,
  lib,
  pkgs,
  options,
  inputs,
  ...
}:

let
  cfg = config.pkgflow.manifestPackages;

  # Load and filter manifest packages by system
  # Returns an attrset of packages that match the current system
  loadManifest =
    manifestFile: requireSystemMatch:
    if manifestFile == null then
      { }
    else
      let
        manifest = lib.importTOML manifestFile;
        packages = manifest.install or { };

        # System matching logic
        # Always respect systems attribute when present (don't install unsupported packages)
        # requireSystemMatch only controls packages WITHOUT systems attribute:
        #   - false: Include packages without systems attribute
        #   - true: Exclude packages without systems attribute
        systemMatches =
          attrs:
          if attrs ? systems then
            # If package has systems attribute, always check if current system is supported
            lib.elem pkgs.system attrs.systems
          else
            # Package has no systems attribute - use requireSystemMatch to decide
            !requireSystemMatch;
      in
      lib.filterAttrs (_: systemMatches) packages;

  # Process manifest and resolve packages
  processManifest =
    manifestCfg:
    let
      systemFilteredPackages = loadManifest manifestCfg.manifestFile manifestCfg.requireSystemMatch;

      # Unified package resolution
      resolvePackage =
        name: attrs:
        if attrs ? flake then
          # Flake package resolution
          let
            hasInput = inputs ? ${name};
            pkg = lib.attrByPath [ name "packages" pkgs.system "default" ] null inputs;
          in
          if pkg != null then
            pkg
          else if !hasInput then
            # Input not found - provide helpful error
            builtins.trace ''
              pkgflow: Flake package '${name}' not found in flake inputs.

              The manifest references: ${name}.flake = "${attrs.flake}"
              But '${name}' is not available in your flake inputs.

              To fix this, add to your flake.nix:
                inputs.${name}.url = "${attrs.flake}";
                inputs.${name}.inputs.nixpkgs.follows = "nixpkgs";

              Then run: nix flake update ${name}
            '' null
          else
            # Input exists but package not found in it
            builtins.trace ''
              pkgflow: Package not found in flake input '${name}'.

              Tried to resolve: ${name}.packages.${pkgs.system}.default
              But it doesn't exist in the flake output.

              Check if the flake provides packages for ${pkgs.system}.
            '' null
        else
          # Regular nixpkgs package resolution
          let
            parts =
              if builtins.isList attrs.pkg-path then attrs.pkg-path else lib.splitString "." attrs.pkg-path;
          in
          lib.attrByPath parts null pkgs;

      resolvedPackages = lib.filter (pkg: pkg != null) (
        lib.mapAttrsToList resolvePackage systemFilteredPackages
      );
    in
    resolvedPackages;
in
{
  options.pkgflow.manifestPackages = {
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

        Examples:
          - Package with systems = ["aarch64-darwin", "x86_64-linux"]:
            Always checked against current system, regardless of this option.
          - Package without systems attribute:
            Installed when false, skipped when true.
      '';
    };
  };

  options.pkgflow.caches = {
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

        Context behavior:
        - System context with onlyTrusted=true: Sets trusted-substituters and trusted-public-keys
        - System context with onlyTrusted=false + enable=true: Sets substituters and trusted-public-keys
        - Home context: onlyTrusted is ignored, enable controls everything

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

        Cache details:
        - substituter: https://nix-community.cachix.org
        - trusted-key: nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
      '';
    };

    mapping = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            flake = lib.mkOption {
              type = lib.types.str;
              description = "Flake reference (e.g., github:helix-editor/helix)";
              example = "github:helix-editor/helix";
            };
            substituter = lib.mkOption {
              type = lib.types.str;
              description = "Binary cache URL";
              example = "https://helix.cachix.org";
            };
            trustedKey = lib.mkOption {
              type = lib.types.str;
              description = "Public key for the binary cache";
              example = "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs=";
            };
          };
        }
      );
      default = import ./config/caches.nix;
      description = ''
        Mapping of flake references to binary caches and trusted keys.
        Defaults to ./config/caches.nix.

        Users can override or extend this list in their configuration.
      '';
      example = lib.literalExpression ''
        [
          {
            flake = "github:helix-editor/helix";
            substituter = "https://helix.cachix.org";
            trustedKey = "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs=";
          }
        ]
      '';
    };
  };

  config =
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

      manifestCfg = cfg // {
        manifestFile = actualManifestFile;
      };

      # Detect context
      isHomeManager = options ? home.packages;
      isSystem = !isHomeManager && (options ? environment.systemPackages);
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
          {
            assertion = (options ? home.packages) || (options ? environment.systemPackages);
            message = ''
              pkgflow.manifestPackages: Cannot detect installation context.

              This module requires either:
              - home-manager (home.packages option)
              - NixOS/nix-darwin (environment.systemPackages option)

              Make sure you're using this module in a supported context.
            '';
          }
        ];
      }

      # Install packages based on context detection
      # Check if home.packages option exists (home-manager context)
      # Otherwise use environment.systemPackages (NixOS/Darwin context)
      (lib.optionalAttrs (options ? home.packages) {
        home.packages = processManifest manifestCfg;
      })
      (lib.optionalAttrs (!(options ? home.packages) && options ? environment.systemPackages) {
        environment.systemPackages = processManifest manifestCfg;
      })

      # Binary cache configuration
      # Only compute when actualManifestFile exists to avoid infinite recursion
      (lib.mkIf (actualManifestFile != null) (
        let
          cacheCfg = config.pkgflow.caches;

          # Compute cache settings
          # Note: Always use requireSystemMatch=false for cache detection
          # We want to configure caches for ALL flakes in the manifest,
          # not just the ones being installed on this system
          systemFilteredPackages = loadManifest actualManifestFile false;
          flakePackages = lib.filterAttrs (_: attrs: attrs ? flake) systemFilteredPackages;
          flakeRefs = lib.mapAttrsToList (_name: attrs: attrs.flake) flakePackages;

          # Match flake packages against cache mapping
          matchedCaches = lib.filter (
            cache: builtins.elem cache.flake flakeRefs
          ) cacheCfg.mapping;

          # Auto-detect nix-community flakes
          hasNixCommunityFlake = lib.any (
            flakeRef: lib.hasPrefix "github:nix-community/" flakeRef
          ) flakeRefs;

          # Determine if we should add nix-community cache
          shouldAddNixCommunity =
            if cacheCfg.addNixCommunity == null then
              hasNixCommunityFlake
            else
              cacheCfg.addNixCommunity;

          # Add nix-community cache based on shouldAddNixCommunity
          nixCommunityCaches = lib.optionals shouldAddNixCommunity [
            {
              substituter = "https://nix-community.cachix.org";
              trustedKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
            }
          ];

          # Combine matched caches with nix-community cache
          allCaches = matchedCaches ++ nixCommunityCaches;

          # Extract substituters and keys
          substituters = lib.unique (map (cache: cache.substituter) allCaches);
          trustedKeys = lib.unique (map (cache: cache.trustedKey) allCaches);

          hasMatches = (builtins.length allCaches) > 0;
        in
        lib.mkMerge [
          # System context with onlyTrusted: set trusted-substituters and trusted-public-keys
          (lib.mkIf (isSystem && cacheCfg.onlyTrusted && hasMatches) {
            nix.settings = {
              trusted-substituters = substituters;
              trusted-public-keys = trustedKeys;
            };
          })

          # System context with enable (not onlyTrusted): set substituters and trusted-public-keys
          (lib.mkIf (isSystem && cacheCfg.enable && !cacheCfg.onlyTrusted && hasMatches) {
            nix.settings = {
              substituters = substituters;
              trusted-public-keys = trustedKeys;
            };
          })

          # Home-manager context with enable: set substituters and trusted-public-keys
          (lib.mkIf (isHomeManager && cacheCfg.enable && hasMatches) {
            nix.settings = {
              substituters = substituters;
              trusted-public-keys = trustedKeys;
            };
          })
        ]
      ))
    ];
}
