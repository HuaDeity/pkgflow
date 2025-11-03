# Default binary cache mappings for common flakes
# Users can override this by setting pkgflow.caches.mapping in their configuration
#
# Note: github:nix-community/* flakes are automatically detected and use nix-community.cachix.org
# by default (controlled by pkgflow.caches.autoAddNixCommunity option)
[
  {
    flake = "github:helix-editor/helix";
    substituter = "https://helix.cachix.org";
    trustedKey = "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs=";
  }
]
