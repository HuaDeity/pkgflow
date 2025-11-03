# Pkgflow library functions
{ lib, pkgs, inputs }:

let
  # Load and filter manifest packages by system
  loadManifest =
    manifestFile: requireSystemMatch:
    if manifestFile == null then
      { }
    else
      let
        manifest = lib.importTOML manifestFile;
        packages = manifest.install or { };

        # System matching logic
        systemMatches =
          attrs:
          if attrs ? systems then
            lib.elem pkgs.system attrs.systems
          else
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
      systemFilteredPackages = loadManifest manifestFile requireSystemMatch;
      resolvedPackages = lib.filter (pkg: pkg != null) (
        lib.mapAttrsToList resolvePackage systemFilteredPackages
      );
    in
    resolvedPackages;

  # Compute cache configuration from manifest file
  computeCaches =
    {
      manifestFile,
      cacheMapping,
      addNixCommunity ? null,
    }:
    if manifestFile == null then
      {
        substituters = [ ];
        trustedKeys = [ ];
        hasMatches = false;
      }
    else
      let
        # Load manifest without system filtering (we want caches for ALL flakes)
        systemFilteredPackages = loadManifest manifestFile false;
        flakePackages = lib.filterAttrs (_: attrs: attrs ? flake) systemFilteredPackages;
        flakeRefs = lib.mapAttrsToList (_name: attrs: attrs.flake) flakePackages;

        # Match flake packages against cache mapping
        matchedCaches = lib.filter (cache: builtins.elem cache.flake flakeRefs) cacheMapping;

        # Auto-detect nix-community flakes
        hasNixCommunityFlake = lib.any (flakeRef: lib.hasPrefix "github:nix-community/" flakeRef) flakeRefs;

        # Determine if we should add nix-community cache
        shouldAddNixCommunity = if addNixCommunity == null then hasNixCommunityFlake else addNixCommunity;

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
      {
        inherit substituters trustedKeys hasMatches;
      };
in
{
  inherit loadManifest resolvePackage processManifest computeCaches;
}
