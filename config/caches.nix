# Default binary cache mappings for common flakes
# Users can override this by setting pkgflow.caches.mapping in their configuration
[
  {
    flake = "github:helix-editor/helix";
    substituter = "https://helix.cachix.org";
    trustedKey = "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs=";
  }
  {
    flake = "github:nix-community/neovim-nightly-overlay";
    substituter = "https://neovim-nightly.cachix.org";
    trustedKey = "neovim-nightly.cachix.org-1:feIoInHRevVEplgdZvQDjhp11kYASYCE2NGY9hNrwxY=";
  }
]
