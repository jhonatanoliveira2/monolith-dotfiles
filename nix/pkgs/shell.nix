{
  lib,
  stdenvNoCC,
  bash,
}:
stdenvNoCC.mkDerivation {
  pname = "monolith-shell";
  version = "1";
  src = lib.cleanSource ../../configs/.config/quickshell;
  buildInputs = [ bash ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/monolith
    cp -r . $out/share/monolith/quickshell
    patchShebangs --host $out/share/monolith/quickshell/scripts
    runHook postInstall
  '';
  passthru.configDir = "share/monolith/quickshell";
  meta = {
    description = "MONOLITH Shell: Quickshell configuration (bar, menus, settings, widgets)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
