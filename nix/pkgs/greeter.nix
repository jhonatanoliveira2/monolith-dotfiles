# QML tree of the greeter: greeter/ plus the shell's own components (Txt, Btn, Avatar), copied from the shell
# package so the login looks exactly like the bar's menus. The NixOS module (nix/modules/nixos/greeter.nix)
# writes the config JSON and runs it with Quickshell inside cage under greetd.
{
  lib,
  stdenvNoCC,
  shell,
  branding,
}:
stdenvNoCC.mkDerivation {
  pname = "monolith-greeter";
  version = "1";
  src = lib.cleanSource ../../greeter;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    dir=$out/share/monolith/greeter
    mkdir -p $dir/components
    cp -r . $dir/
    for c in Txt Btn Avatar; do
      cp ${shell}/${shell.configDir}/components/$c.qml $dir/components/
    done
    runHook postInstall
  '';
  passthru = {
    configDir = "share/monolith/greeter";
    inherit branding;
  };
  meta = {
    description = "MONOLITH greeter (Quickshell, for greetd)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
