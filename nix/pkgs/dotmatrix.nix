# monolith-dotmatrix (nix/nothing/dotmatrix.py) with Python, numpy and Pillow: the build renders the
# wallpapers with it (nix/pkgs/nothing-wallpapers.nix) and wallpaper-menu calls it at runtime (on PATH).
{
  lib,
  stdenvNoCC,
  python3,
}:
let
  python = python3.withPackages (ps: [
    ps.numpy
    ps.pillow
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "monolith-dotmatrix";
  version = "1";
  src = ../nothing/dotmatrix.py;
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/monolith-dotmatrix
    substituteInPlace $out/bin/monolith-dotmatrix --replace-fail "#!/usr/bin/env python3" "#!${python}/bin/python3 -I"
    runHook postInstall
  '';
  passthru = { inherit python; };
  meta = {
    description = "Render still pictures as LED dot matrices (MONOLITH Nothing theme)";
    license = lib.licenses.mit;
    mainProgram = "monolith-dotmatrix";
    platforms = lib.platforms.all;
  };
}
