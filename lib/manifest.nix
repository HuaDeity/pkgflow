# Shared functions for loading and processing package manifests
{ lib, pkgs, inputs }:

{
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

  # Resolve a single package from manifest entry to actual derivation
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

  # Process manifest and return list of resolved packages
  processManifest =
    manifestFile: requireSystemMatch:
    let
      systemFilteredPackages = lib.pkgflow.loadManifest manifestFile requireSystemMatch;
      resolvedPackages = lib.filter (pkg: pkg != null) (
        lib.mapAttrsToList lib.pkgflow.resolvePackage systemFilteredPackages
      );
    in
    resolvedPackages;
}
