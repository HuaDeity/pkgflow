# Default Darwin module that imports all Flox manifest modules
{ ... }:

{
  imports = [
    ./shared.nix
    ./darwin.nix
  ];
}
