# monolith-cava (nix/nothing/cava-dots.py): cava drawn as columns of LEDs in the terminal (Nothing theme);
# cava itself does the audio analysis and is put on its PATH.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  cava,
}:
stdenvNoCC.mkDerivation {
  pname = "monolith-cava";
  version = "1";
  src = ../nothing/cava-dots.py;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/monolith-cava
    substituteInPlace $out/bin/monolith-cava --replace-fail "#!/usr/bin/env python3" "#!${python3}/bin/python3 -I"
    wrapProgram $out/bin/monolith-cava --prefix PATH : ${lib.makeBinPath [ cava ]}
    runHook postInstall
  '';
  meta = {
    description = "cava drawn as LEDs (MONOLITH Nothing theme)";
    license = lib.licenses.mit;
    mainProgram = "monolith-cava";
    platforms = lib.platforms.linux;
  };
}
