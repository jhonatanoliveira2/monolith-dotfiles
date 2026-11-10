# MONOLITH Dots: the cursor theme of the Nothing theme (XCursor), drawn at build time by nix/nothing/cursor.py:
# a "+" of LEDs as the pointer and LED shapes for text, links, waiting, moving and resizing.
{
  lib,
  runCommand,
  python3,
}:
let
  python = python3.withPackages (ps: [ ps.pillow ]);
in
runCommand "monolith-dots-cursors"
  {
    nativeBuildInputs = [ python ];
    passthru.themeName = "Monolith-Dots";
    meta = {
      description = "LED cursor theme of the MONOLITH Nothing theme";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
  ''
    python3 -I ${../nothing/cursor.py} $out/share/icons/Monolith-Dots --name Monolith-Dots
  ''
