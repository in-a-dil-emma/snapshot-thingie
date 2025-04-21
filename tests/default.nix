let
  inputs = import ../npins;
  pkgs = import inputs.nixpkgs {};
  inherit (pkgs.testers) runNixOSTest;
in runNixOSTest {
  name = "NixOS test";

  defaults = {
    services.snapshot-thingie = {
      enable = true;
      users = [ "user" ];
    };
    users.users."user" = {
      isNormalUser = true;
    };
  };

  nodes = {
  };

  testScript = ''
  '';
}
