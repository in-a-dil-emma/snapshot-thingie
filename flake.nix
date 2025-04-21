{
  inputs = {
    systems.url = "github:nix-systems/default-linux";
  };

  outputs = { self, systems }: let
    inputs = import ./npins;
    lib = import (inputs.nixpkgs + /lib);
    nixosSystem = import (inputs.nixpkgs + "/nixos/lib/eval-config.nix");

    inherit (lib) genAttrs;

    genSystems = f: genAttrs (import systems) (system: f (import inputs.nixpkgs { inherit system; }));
  in {
    devShell = genSystems ({ callPackage, ... }: callPackage ./shell.nix {});

    nixosModules = {
      snapshot-thingie = ./src/modules/nixos.nix;
    };

    checks = genSystems ({ callPackage, testers, system, ... }: {
      nixos-tests = callPackage ./tests/nixos.nix {};
    });
    
    nixosConfigurations.shell = nixosSystem {
      system = "x86_64-linux";
      inherit lib;
      modules = [
        ({ modulesPath, ... }: { imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ]; })

        self.nixosModules.snapshot-thingie

        ./vm/configuration.nix
      ];
    };
  };
}
