# Pkgflow library functions
{ lib, pkgs, inputs }:

let
  manifest = import ./manifest.nix { inherit lib pkgs inputs; };
  caches = import ./caches.nix { inherit lib; };
in
manifest // caches
