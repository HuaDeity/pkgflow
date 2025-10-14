# Default module that imports all Flox manifest modules
{ ... }:

{
  imports = [
    ./shared.nix
    ./home.nix
  ];
}
