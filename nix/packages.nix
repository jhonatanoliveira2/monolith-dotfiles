# User programs of the MONOLITH Shell, required and optional (programs.monolith.optionalPackages). System services (Hyprland, PipeWire,
# NetworkManager, BlueZ, UPower, udisks, power-profiles-daemon, the portal, polkit) are enabled by the NixOS
# module instead (nix/modules/nixos/system.nix); these are the user programs Home Manager installs.
pkgs: {
  required = with pkgs; [
    # compositor tools, shell, lock screen (Hyprland itself comes from programs.hyprland)
    quickshell
    hyprlock
    hypridle
    lxqt.lxqt-policykit # autostart.lua: lxqt-policykit-agent
    qt6Packages.qt6ct # environment.lua: QT_QPA_PLATFORMTHEME=qt6ct
    git
    # launcher, terminal, shell
    rofi # SUPER+A launcher and wallpaper-menu
    ghostty
    fish
    starship
    atuin
    # files, theming, fonts
    nautilus
    materia-theme # gtk-theme Materia-dark (Nautilus transparency in gtk-4.0/gtk.css)
    dconf
    zenity # Settings > Profile > Choose (the portal's file chooser, xdg-desktop-portal-gtk)
    nerd-fonts.jetbrains-mono
    material-icons
    # screenshots, clipboard, notifications
    grim
    slurp
    wl-clipboard
    libnotify
    jq
    ffmpeg
    imagemagick # monolith-theme: video frames / palettes
    # audio, media, brightness, network, disks
    wireplumber # wpctl
    pipewire # pw-loopback, pipewire (FxChain filter units)
    pulseaudio # pactl only (the server is PipeWire's pipewire-pulse)
    playerctl
    brightnessctl
    networkmanagerapplet # nm-connection-editor
    blueman
    bluez # bluetoothctl
    curl
    udisks # udisksctl: SMART / NVMe wear in Settings > Storage
    pciutils # lspci: GPU name in Settings > System
    # wallpapers and dynamic palette
    awww # awww-daemon (static wallpapers)
    mpvpaper # animated wallpapers
    wpgtk # Settings > Themes, dynamic palette
    # small tools the shell's scripts call
    glib # gsettings, gdbus, gio trash
    util-linux # lsblk, script, setsid, flock
    iproute2
    procps
    xdg-utils
    gawk
    gnused
    findutils
  ];

  optional = with pkgs; [
    rnnoise-plugin # noise suppression in Settings > Microphone (LADSPA)
    cava # audio spectrum when a song has no lyrics
    pavucontrol # "Audio mixer" button
    fastfetch
    btop
    micro
    neovim
    gcc # nvim-treesitter
    tree-sitter
    ripgrep
    fd
    nwg-look
    # opening files from Nautilus (double-click): images, videos, PDFs, office documents, video thumbnails
    loupe # images (GNOME Image Viewer)
    mpv # videos and audio
    papers # PDFs (GNOME Document Viewer; also draws the PDF thumbnails)
    libreoffice # documents, spreadsheets and presentations
    ffmpegthumbnailer # video thumbnails in Nautilus
  ];
}
