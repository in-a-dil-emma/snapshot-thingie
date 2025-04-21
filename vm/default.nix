let
  inputs = import ../npins;
  pkgs = import inputs.nixpkgs {};
  lib = import (inputs.nixpkgs + "/lib");
  inherit (pkgs) mkShellNoCC nixos;
  inherit (lib) getExe;

  vm = nixos [
    ({ modulesPath, ... }: { imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ]; })
    ../src/modules/nixos.nix
    ./configuration.nix
  ];
in mkShellNoCC {
  name = "vm";
  shellHook = "exec ${getExe vm.config.system.build.vm}";
}
