# Pkgflow library functions
{
  lib,
  pkgs,
  inputs,
}:

let
  # Load and filter manifest packages by system
  # Simple logic: if package has systems attribute, filter by it. Otherwise, include it.
  loadManifest =
    manifestFile:
    if manifestFile == null then
      { }
    else
      let
        manifest = lib.importTOML manifestFile;
        packages = manifest.install or { };

        # System matching logic
        # If package specifies systems, check if current system is supported
        # If package doesn't specify systems, assume it works everywhere
        systemMatches = attrs: if attrs ? systems then lib.elem pkgs.system attrs.systems else true;
      in
      lib.filterAttrs (_: systemMatches) packages;

  # Process entire manifest in one pass
  # Returns: { nixPackages = [...]; homebrewFormulas = [...]; homebrewCasks = [...]; flakePackages = {...}; }
  processManifest =
    {
      manifestPackages,
      shouldInstallNixpkgs,
      shouldInstallFlakes,
      wantsBrewForNixpkgs,
      wantsBrewForFlakes,
      homebrewMapping,
    }:
    let
      processPackage =
        name: attrs:
        let
          isFlake = attrs ? flake;
          shouldInstall = if isFlake then shouldInstallFlakes else shouldInstallNixpkgs;

          # Get lookup key (for both nix resolution and brew mapping)
          lookupKey =
            attrs.flake or (
              if builtins.isList attrs.pkg-path then
                builtins.concatStringsSep "." attrs.pkg-path
              else
                attrs.pkg-path
            );

          # Determine if this package should go to brew
          packageTypeWantsBrew = if isFlake then wantsBrewForFlakes else wantsBrewForNixpkgs;
          brewInfo = homebrewMapping.${lookupKey} or null;
          brewVal = if brewInfo ? brew then brewInfo.brew else true;
          shouldBrew = shouldInstall && packageTypeWantsBrew && brewVal != false && brewVal != null;

          # Resolve to nix package if needed
          nixPackage =
            if shouldInstall && !shouldBrew then
              (
                if isFlake then
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
                      if builtins.isList attrs.pkg-path then
                        attrs.pkg-path
                      else
                        lib.splitString "." attrs.pkg-path;
                  in
                  lib.attrByPath parts null pkgs
              )
            else
              null;

          # Convert to brew format if needed
          brewConverted =
            if shouldBrew then
              let
                mapping =
                  if brewInfo != null then
                    brewInfo
                  else
                    {
                      brew = lookupKey;
                      type = "formula";
                    };
                formatted =
                  if mapping ? args then
                    {
                      name = mapping.brew;
                      args = mapping.args;
                    }
                  else
                    mapping.brew;
              in
              {
                inherit formatted;
                type = mapping.type or "formula";
              }
            else
              null;
        in
        {
          inherit nixPackage brewConverted isFlake;
          flakeRef = if isFlake then attrs.flake else null;
        };

      # Process all packages in one pass
      processed = lib.mapAttrs processPackage manifestPackages;

      # Extract results
      nixPackagesList = lib.filter (p: p != null) (lib.mapAttrsToList (_: v: v.nixPackage) processed);
      brewList = lib.filter (b: b != null) (lib.mapAttrsToList (_: v: v.brewConverted) processed);

      # Split brew into formulas and casks
      formulas = lib.map (b: b.formatted) (lib.filter (b: (b.type or "formula") == "formula") brewList);
      casks = lib.map (b: b.formatted) (lib.filter (b: (b.type or "") == "cask") brewList);

      # Collect flake packages for cache computation (from original manifest)
      flakePackages = lib.filterAttrs (_: attrs: attrs ? flake) manifestPackages;
    in
    {
      nixPackages = nixPackagesList;
      homebrewFormulas = formulas;
      homebrewCasks = casks;
      inherit flakePackages;
    };

  # Compute cache configuration from flake packages
  computeCaches =
    {
      flakePackages,
      cacheMapping,
      addNixCommunity ? null,
    }:
    if flakePackages == { } then
      {
        substituters = [ ];
        trustedKeys = [ ];
        hasMatches = false;
      }
    else
      let
        # Extract flake refs from flake packages
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
  inherit loadManifest processManifest computeCaches;
}
