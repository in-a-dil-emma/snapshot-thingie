{ pkgs, lib, ... }: {
  virtualisation = {
    graphics = false;
    cores = 8;
    memorySize = 8096 * 2;
    diskSize = 64 * 1024;
    qemu = {
      consoles = [ "tty0" "hvc0" ];
      options = [
        "-serial null"
        "-device virtio-serial"
        "-chardev stdio,mux=on,id=char0,signal=off"
        "-mon chardev=char0,mode=readline"
        "-device virtconsole,chardev=char0,nr=0"
      ];
    };
  };

  boot.kernelParams = [ "loglevel=3" ];

  services.snapshot-thingie = {
    enable = true;
    users = [ "user" ];
  };

  # Dev env stuff
  environment.loginShellInit = ''
    trap 'sudo poweroff' EXIT
  '';

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  environment.systemPackages = with pkgs; [
    tmux ncdu xdg-utils
  ];

  networking.networkmanager.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      theme = "flazz";
    };
  };

  services.getty.autologinUser = "user";
  users.users."user" = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "password";
    shell = pkgs.zsh;
  };

  boot.tmp.useTmpfs = true;

  system.stateVersion = lib.trivial.release;
}
