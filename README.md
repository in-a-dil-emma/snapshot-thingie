# snapshot thing

*Extracted from my nixos config.*

The most flakes you'll get:

```console
$ nix flake show
git+file:///.../snapshot-thingie
└───nixosModule: NixOS module
```

## INSTALLING

Add the module using npins:
```console
$ npins add github in-a-dil-emma snapshot-thingie -b dev
```

Or flakes:

```nix
{
  inputs = {
    snapshots.url = "github:in-a-dil-emma/snapshot-thingie/dev";
  };
}
```

## CONFIGURING

Consult [options.nix](module/options.nix).
