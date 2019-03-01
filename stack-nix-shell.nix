# This is the shell file specified in the stack.yaml file.
# This runs stack commands in an environment created with nix.

{ }:

let
  nixpkgs = import (builtins.fetchTarball "channel:nixos-19.03") {};
in

with nixpkgs;

haskell.lib.buildStackProject {
  name = "termonad";
  ghc = nixpkgs.haskell.compiler.ghc844;
  nativeBuildInputs = [ git ];
  buildInputs = [ gobjectIntrospection glib zlib ];
}
