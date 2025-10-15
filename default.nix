# Default module that imports all pkgflow manifest modules
# Works for both home-manager and NixOS/nix-darwin
{ config, lib, ... }:

{
  imports = [
    ./shared.nix
    ./home.nix
  ] ++ lib.optionals (lib.hasAttr "darwin" config || lib.hasAttr "homebrew" config) [
    # Auto-import Darwin module if in nix-darwin context
    ./darwin.nix
  ];
}
