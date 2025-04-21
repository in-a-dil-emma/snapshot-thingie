{ nixosTest }:

nixosTest {
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
