snapshot thing

extracted from my nixos config

consult [options.nix](src/options.nix)

The most flakes you'll get:

```console
$ nix flake show
git+file:///.../snapshot-thingie
└───nixosModules
    └───snapshot-thingie: NixOS module
```

Adding a flake.nix SOMEHOW slows down direnv.
