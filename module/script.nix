{ config, pkgs, lib, user }: let
  inherit (builtins) toString;
  inherit (lib) getExe makeBinPath escapeShellArgs;
  inherit (pkgs) runCommand shellcheck util-linux findutils gawk;

  cfg = config.services.snapshot-thingie;
in runCommand "snaphot-script" {
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
    --subst-var-by trashDirs   "${escapeShellArgs cfg.trashDirs}" \
    --subst-var-by debug       "${if cfg.debug then "true" else "false"}" \
    --subst-var-by extraPATH   "${makeBinPath [ util-linux findutils gawk ]}"
  chmod 755 $out/bin/create-snapshot
  ${getExe shellcheck} --exclude=SC2164 $out/bin/create-snapshot
  patchShebangs $out/bin/create-snapshot
''