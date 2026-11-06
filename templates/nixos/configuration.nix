{ pkgs, ... }:
let
  user = "alice"; # your user name
in
{
  system.stateVersion = "25.11"; # keep the value of your first install

  # Bootloader: the MONOLITH GRUB theme applies when GRUB is used (systemd-boot keeps working, unthemed).
  # UEFI (ESP mounted at /boot), as below. BIOS: device = "/dev/sda" (the disk), efiSupport = false and
  # remove the canTouchEfiVariables line. Check with: [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "monolith-pc";
  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "pt_BR.UTF-8";
  services.xserver.xkb.layout = "br"; # also the greeter's keyboard
  console.keyMap = "br-abnt2";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # after nixos-install, set the password: nixos-enter --root /mnt -c 'passwd alice' (the greeter needs one)
  users.users.${user} = {
    isNormalUser = true;
    description = "Alice";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    shell = pkgs.fish;
  };

  monolith = {
    enable = true; # Hyprland + services, fonts, portals
    language = "pt"; # boot menu, splash prompts and greeter
    homeUsers = [ user ]; # programs.monolith.enable for these users
    boot.enable = true; # GRUB theme, Plymouth, silent boot, "recovery" entry
    greeter.enable = true; # Quickshell greeter on greetd
    greeter.defaultUser = user;
    # battery.chargeLimit = 80;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "pre-monolith"; # files already in ~/.config are renamed, not overwritten
    users.${user} = {
      home.stateVersion = "25.11";
      programs.monolith = {
        apps.browser = "firefox";
        # the flake lives in /etc/nixos after an install from the ISO (use ~/nixos if you keep it there)
        updateCommand = "sudo nix flake update monolith --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos";
      };
    };
  };
}
