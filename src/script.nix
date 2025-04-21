{ config, user, system }: let
  inputs = import ../npins;
  pkgs = import inputs.nixpkgs { inherit system; };

  inherit (builtins) map toString;
  inherit (pkgs) runCommandNoCC shellcheck util-linux findutils gawk;
  inherit (pkgs.lib) getExe makeBinPath concatStringsSep escapeShellArg pipe;

  cfg = config.services.snapshot-thingie;
in runCommandNoCC "snaphot-script" {
  meta.mainProgram = "create-snapshot";
} ''
  mkdir -p $out/bin
  substitute ${./script.bash} $out/bin/create-snapshot      \
    --subst-var-by snapshotDir "${cfg.prefix}"              \
    --subst-var-by userGroup   "${user.group}"              \
    --subst-var-by userHome    "${user.home}"               \
    --subst-var-by userName    "${user.name}"               \
    --subst-var-by keepWeeks   "${toString cfg.keep.weeks}" \
    --subst-var-by keepDays    "${toString cfg.keep.days}"  \
    --subst-var-by debug       "${if cfg.debug then "true" else "false"}" \
    --subst-var-by trashDirs   "${pipe cfg.trashDirs [ (map escapeShellArg) (concatStringsSep " ") ]}" \
    --subst-var-by extraPATH   "${makeBinPath [ util-linux findutils gawk ]}"
  chmod 755 $out/bin/create-snapshot
  ${getExe shellcheck} --exclude=SC2164,SC2207 $out/bin/create-snapshot
  patchShebangs $out/bin/create-snapshot
''
