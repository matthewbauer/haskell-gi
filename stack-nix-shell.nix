# This is the shell file specified in the stack.yaml file.
# This runs stack commands in an environment created with nix.

{ pkgs ? null }:

let
  # recent version of nixpkgs as of 2018-10-17
  nixpkgsTarball = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6a23e11e658b7a7a77f1b61d30d64153b46bc852.tar.gz";
    sha256 = "03n4bacfk1bbx3v0cx8xcgcmz44l0knswzh7hwih9nx0hj3x41yc";
  };

  nixpkgs =
    if pkgs == null
    then import nixpkgsTarball {}
    else import pkgs {};
in

with nixpkgs;

haskell.lib.buildStackProject {
  name = "termonad";
  nativeBuildInputs = [
    # cairo
    git
    # gnome3.vte
    gobjectIntrospection
    # gtk3
    zlib
  ];
}
