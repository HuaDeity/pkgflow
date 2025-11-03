# Shared functions for binary cache configuration
{ lib }:

{
  # Compute cache configuration from manifest file
  # Returns { substituters = [...]; trustedKeys = [...]; hasMatches = bool; }
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
        systemFilteredPackages = lib.pkgflow.loadManifest manifestFile false;
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
}
