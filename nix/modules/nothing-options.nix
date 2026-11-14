# Options of the "Nothing" theme (dot matrix / LED identity), shared by the NixOS module (monolith.nothingTheme,
# forwarded to Home Manager) and the Home Manager one (programs.monolith.nothingTheme). Everything but the
# fonts, `enable` and the build-time wallpapers can also be changed at runtime in Settings > Themes > Nothing;
# these values are the defaults the shell starts from (and "Reset" returns to).
{ lib }:
let
  inherit (lib) mkOption types;
  hex = types.strMatching "#?[0-9a-fA-F]{6}";
in
{
  enable = mkOption {
    type = types.bool;
    default = false;
    description = ''
      The Nothing theme: greys, dot-matrix type (Doto, Space Grotesk, Space Mono), LED meters, an optional
      light around the screen edge and dot-matrix wallpapers. Off = the shell as before (no fonts, no rendering).
    '';
  };
  led = {
    size = mkOption {
      type = types.ints.between 1 64;
      default = 6;
      description = "LED diameter in px (wallpapers; the interface's LED meters scale it to their height).";
    };
    spacing = mkOption {
      type = types.ints.between 0 64;
      default = 3;
      description = "Gap between LEDs in px.";
    };
    shape = mkOption {
      type = types.enum [
        "circle"
        "square"
        "rounded"
      ];
      default = "circle";
      description = "LED shape.";
    };
  };
  monochrome = mkOption {
    type = types.bool;
    default = true;
    description = ''
      Grey palette for the whole shell (overrides Settings > Themes) and grey wallpaper LEDs. Off: the colour
      theme in use stays and wallpaper LEDs take the picture's hues.
    '';
  };
  cursor = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "MONOLITH Dots cursors: a \"+\" of LEDs as the pointer (Hyprland, GTK, Qt). Requires a rebuild.";
    };
    size = mkOption {
      type = types.ints.between 16 96;
      default = 24;
      description = "Cursor size in px (24 / 28 / 32 / 48 / 64 / 96 are drawn; others are scaled).";
    };
  };
  icons = mkOption {
    type = types.bool;
    default = true;
    description = "MONOLITH Dots Icons: folders, files and devices as LED matrices (Nautilus, GTK apps). Requires a rebuild.";
  };
  nautilus = mkOption {
    type = types.bool;
    default = true;
    description = "Nautilus in OLED black at 85 % opacity, a light glass instead of the default theme's (nix/nothing/nautilus.css after the default gtk-4.0/gtk.css). Requires a rebuild.";
  };
  fastfetch = mkOption {
    type = types.bool;
    default = true;
    description = "fastfetch in the Nothing style: the NixOS snowflake as LEDs, LED bars for memory and disk. Requires a rebuild.";
  };
  cava = mkOption {
    type = types.bool;
    default = true;
    description = ''
      cava (the terminal audio visualizer) in the Nothing style: `cava` in fish opens monolith-cava, which draws
      the bars as columns of LEDs (`command cava` runs the plain one, in greys). Requires a rebuild.
    '';
  };
  edgeGlow = mkOption {
    type = types.bool;
    default = true;
    description = "A light runs along the screen edge on new notifications (red and twice for critical ones).";
  };
  wallpaper = {
    style = mkOption {
      type = types.enum [
        "dotmatrix"
        "original"
      ];
      default = "dotmatrix";
      description = "dotmatrix: still wallpapers are shown as LED matrices (the files are never changed); original: as they are.";
    };
    dither = mkOption {
      type = types.enum [
        "none"
        "floyd"
        "bayer"
      ];
      default = "none";
      description = "none: LED size and brightness follow the picture; floyd / bayer: whole LEDs, dithered to `levels` steps.";
    };
    levels = mkOption {
      type = types.ints.between 2 16;
      default = 2;
      description = "Brightness steps with dithering (2 = on / off).";
    };
    invert = mkOption {
      type = types.bool;
      default = false;
      description = "Light the dark parts of the picture.";
    };
    contrast = mkOption {
      type = types.ints.between 50 200;
      default = 100;
      description = "Contrast of the wallpapers in % (100 = the original curve; more = blacker blacks, whiter whites).";
    };
    brightness = mkOption {
      type = types.ints.between 50 200;
      default = 100;
      description = "Brightness of the lit LEDs in % (100 = the original).";
    };
    colors = {
      lit = mkOption {
        type = hex;
        default = "f2f2f2";
        description = "Fully lit LED.";
      };
      off = mkOption {
        type = hex;
        default = "141414";
        description = "Unlit LED.";
      };
      background = mkOption {
        type = hex;
        default = "000000";
        description = "Between the LEDs.";
      };
    };
    outputs = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            width = mkOption {
              type = types.ints.positive;
              description = "Native width in px.";
            };
            height = mkOption {
              type = types.ints.positive;
              description = "Native height in px.";
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''{ eDP-1 = { width = 1920; height = 1200; }; DP-1 = { width = 2560; height = 1440; }; }'';
      description = ''
        Monitors (connector name, as in `hyprctl monitors`) whose wallpapers are rendered at build time, at this
        native resolution. Empty: everything is rendered at runtime (first use of each picture, then cached).
        Requires a rebuild.
      '';
    };
    dirs = mkOption {
      type = types.listOf types.path;
      default = [ ../../wallpapers/static ];
      defaultText = lib.literalExpression "[ <repository>/wallpapers/static ]";
      description = "Folders whose still pictures are rendered at build time for `outputs`. Requires a rebuild.";
    };
  };
}
