{ config, pkgs, lib, ... }:

let
  inherit (lib) mkIf mkMerge pipe getExe flatten;
  inherit (pkgs) callPackage;
  inherit (builtins) map;
  
  cfg = config.services.snapshot-thingie;
in

{
  imports = [
    ../options.nix
  ];
  
  config.systemd = {
    services = pipe cfg.users [ (map (x: config.users.users.${x})) (map ({ name, home, ... }@user: {
      "snapshot-home-${name}" = {
        description = "Snapshot ${home}";
        serviceConfig.Type = "exec";
        wants = mkIf cfg.runOnActivation [
          "multi-user.target"
        ];
        after = mkIf cfg.runOnActivation [
          "multi-user.target"
        ];
        wantedBy = mkIf cfg.runOnActivation [
          "multi-user.target"
        ];
        script = getExe (callPackage ../script.nix {
          inherit user config;
        });
        startAt = mkIf (cfg.onCalendar != null) cfg.onCalendar;
      };
    })) mkMerge (mkIf cfg.enable) ];

    timers = pipe cfg.users [ (map (x: config.users.users.${x})) (map ({ name, ... }: {
      "snapshot-home-${name}" = mkIf (cfg.onCalendar != null) {
        unitConfig = {
          Wants = [
            "multi-user.target"
          ];
          After = [
            "multi-user.target"
          ];
        };
        timerConfig = {
          OnCalendar = cfg.onCalendar;
          Persistent = true;
        };
      };
    })) mkMerge (mkIf cfg.enable) ];
  };

  config.systemd.tmpfiles.rules =
    (pipe cfg.users [
      (map (elem: config.users.users.${elem}))
      (map (
        user: [
          "d ${cfg.prefix}/${user.name} 0755 ${user.name} ${user.group} - -"
          "x ${cfg.prefix}/${user.name} -    -            -             - -"
        ]
      ))
      flatten
    ])
    ++ [
      "d  ${cfg.prefix}        0755 root root - -"
      "d! ${cfg.prefix}/.trash 1777 root root 0 -"
    ];
}
