{ inputs ? import ./npins }: let
  pkgs = import inputs.nixpkgs {};
  inherit (pkgs) mkShellNoCC npins;
in mkShellNoCC {
  packages = [
    npins
  ];
  shellHook = ''
    echo 'test config:
      $ nix-shell vm/shell.nix
    run tests:
      $ nix-build tests'
  '';
  NIX_PATH="nixpkgs=${pkgs.path}";
}
