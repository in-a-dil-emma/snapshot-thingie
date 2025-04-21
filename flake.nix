{
  outputs = _: {
    nixosModules.snapshot-thingie = ./src/modules/nixos.nix;
  };
}
