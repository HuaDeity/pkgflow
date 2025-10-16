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

  processManifest =
    manifestCfg:
    let
      manifestFile = manifestCfg.manifestFile;

      manifest = if manifestFile != null then lib.importTOML manifestFile else { };

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
          !manifestCfg.requireSystemMatch;

      systemFilteredPackages = lib.filterAttrs (_: systemMatches) packages;

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
    ];
}
