{ config, lib, ... }:

let
  inherit (lib) mkOption mkEnableOption all;
  inherit (lib.types) bool nullOr path str ints listOf;

  cfg = config.services.snapshot-thingie;
in {
  options.services.snapshot-thingie = {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable/disable this module.
      '';
    };
    users = mkOption {
      type = listOf str;
    };
    prefix = mkOption {
      type = nullOr path;
      default = "/home/.snapshots";
      description = ''
        Path where to store snapshots. Must be on the same device to take advantage of reflink copies.
      '';
    };
    trashDirs = mkOption {
      type = listOf str;
      default = [ ".cache" ".var/app/*/cache" ];
      description = ''
        List of directories (relative to the snapshot root) to delete.
      '';
    };
    keep = {
      days = mkOption {
        type = ints.positive;
        default = 3;
      };
      weeks = mkOption {
        type = ints.positive;
        default = 2;
      };
    };
    runOnActivation = mkOption {
      type = bool;
      default = false;
    };
    onCalendar = mkOption {
      type = nullOr str;
      default = "daily";
    };
    debug = mkEnableOption "Show more info.";
  };

  config = {
    assertions = [
      { assertion = cfg.runOnActivation || cfg.onCalendar != null; message = "Either onCalendar needs to be set or runOnActivation needs to be enabled"; }
      { assertion = all (elem: config.users.users ? ${elem}) cfg.users; message = "Users must be declared with the users.users option."; }
    ];
  };
}
