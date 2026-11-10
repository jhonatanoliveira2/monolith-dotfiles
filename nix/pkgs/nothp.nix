{ lib, stdenv }:
stdenv.mkDerivation {
  pname = "monolith-nothp";
  version = "1";
  dontUnpack = true;
  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Werror -o monolith-nothp ${./nothp.c}
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 monolith-nothp $out/bin/monolith-nothp
    runHook postInstall
  '';
  meta = {
    description = "Run a program with transparent huge pages disabled (used to start the MONOLITH Shell)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "monolith-nothp";
  };
}
