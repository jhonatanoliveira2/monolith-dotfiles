# MONOLITH Dots Icons: the icon theme of the Nothing theme (folders, files, places and devices as LED
# matrices; the rest inherited from Adwaita / hicolor), drawn at build time by nix/nothing/icons.py.
{
  lib,
  runCommand,
  python3,
}:
runCommand "monolith-dots-icons"
  {
    nativeBuildInputs = [ python3 ];
    passthru.themeName = "Monolith-Dots-Icons";
    meta = {
      description = "Monochrome LED icon theme of the MONOLITH Nothing theme";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
  ''
    python3 -I ${../nothing/icons.py} $out/share/icons/Monolith-Dots-Icons --name Monolith-Dots-Icons
  ''
