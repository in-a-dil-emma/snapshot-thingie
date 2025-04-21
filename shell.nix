{ inputs ? import ./npins, system ? builtins.currentSystem }: let
  pkgs = import inputs.nixpkgs { inherit system; };
  inherit (pkgs) mkShellNoCC nixos-shell npins callPackage;
in mkShellNoCC {
  packages = [
    nixos-shell
    npins

    (callPackage ./scripts/run-shell.nix { })
  ];
  shellHook = ''
    echo -e "\033[31mrun-shell\033[0m to run your code in nixos-shell"
  '';
  NIX_PATH="nixpkgs=${pkgs.path}";
}
