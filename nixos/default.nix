{ config, pkgs, lib, ... }:

let
  inherit (lib) mkIf mkMerge pipe getExe flatten optionals;
  inherit (pkgs) callPackage getent findutils;
  inherit (builtins) map;
  
  cfg = config.services.snapshot-thingie;
in

{
  imports = [
    ../module
  ];
  
  config.systemd = {
    tmpfiles.rules =
    (pipe cfg.users [
      (map (elem: config.users.users.${elem}))
      (map (
        user: [
          "d ${cfg.prefix}/${user.name} 0755 ${user.name} ${user.group} - -"
        ]
      ))
      flatten
    ])
    ++ [
      "d  ${cfg.prefix}        0755 root root - -"
      "d! ${cfg.prefix}/.trash 1777 root root 0 -"
    ];
    services = pipe cfg.users [ (map (x: config.users.users.${x})) (map ({ name, home, ... }@user: {
      "snapshot-home-${name}" = {
        description = "Snapshot ${home}";
        serviceConfig.Type = "exec";
        wants = mkIf cfg.runOnActivation [
          "multi-user.target"
        ];
        after = [
          "snapshot-clean-removed-users.service"
          "snapshot-clean-trash.service"
        ] ++ (optionals cfg.runOnActivation [
          "multi-user.target"
        ]);
        wantedBy = mkIf cfg.runOnActivation [
          "multi-user.target"
        ];
        script = getExe (callPackage ../module/script.nix {
          inherit user config;
        });
        startAt = mkIf (cfg.onCalendar != null) cfg.onCalendar;
        serviceConfig.IODeviceWeight = [ "${home} 10" "${cfg.prefix} 10" ];
      };
    })) (services: services ++ [
      {
        "snapshot-clean-trash" = {
          startAt = "hourly";
          path = [ findutils ];
          serviceConfig.IODeviceWeight="${cfg.prefix}/.trash 10";
          script = ''
            find "${cfg.prefix}/.trash" -mindepth 1 -delete
          '';
        };
        "snapshot-clean-removed-users" = {
          startAt = "hourly";
          path = [ getent findutils ];
          serviceConfig.IODeviceWeight="${cfg.prefix}/.trash 10";
          script = ''
            cd "${cfg.prefix}"
            for i in *; do
              if ! getent passwd "$i"; then
                find "$i" -delete
              fi
            done
          '';
        };
      }
    ]) mkMerge (mkIf cfg.enable) ];

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
}