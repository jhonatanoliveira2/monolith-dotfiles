# Monolith Icons: the icon theme of the default theme (flat grey folders, files, places and devices; the
# rest inherited from Adwaita / hicolor), drawn at build time by branding/icons.py.
{
  lib,
  runCommand,
  python3,
}:
runCommand "monolith-icons"
  {
    nativeBuildInputs = [ python3 ];
    passthru.themeName = "Monolith-Icons";
    meta = {
      description = "Flat grey icon theme of the MONOLITH default theme";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
  ''
    python3 -I ${../../branding/icons.py} $out/share/icons/Monolith-Icons --name Monolith-Icons
  ''
