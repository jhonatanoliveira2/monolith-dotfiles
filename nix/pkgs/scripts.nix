# ~/.local/bin helpers of the shell. The shell and the Hyprland binds call them by full path
# (~/.local/bin/...), so the Home Manager module links them there; their tools are appended to PATH
# (--suffix: the user's own versions, e.g. the running Hyprland's hyprctl, still come first).
{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  gawk,
  util-linux,
  procps,
  libnotify,
  jq,
  ffmpeg,
  imagemagick,
  rofi,
  wpgtk,
  awww,
  mpvpaper,
}:
let
  runtime = [
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    util-linux # flock, setsid
    procps # pkill, pgrep
    libnotify
    jq
    ffmpeg
    imagemagick
    rofi
    wpgtk
    awww
    mpvpaper
  ];
in
stdenvNoCC.mkDerivation {
  pname = "monolith-scripts";
  version = "1";
  src = lib.cleanSource ../../configs/.local/bin;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    for f in monolith-theme monolith-vscode wallpaper-menu; do
      install -Dm755 "$f" "$out/bin/$f"
    done
    patchShebangs --host $out/bin
    for f in $out/bin/*; do
      wrapProgram "$f" --suffix PATH : ${lib.makeBinPath runtime}
    done
    runHook postInstall
  '';
  meta = {
    description = "MONOLITH Shell helpers: wallpaper picker backend, palette generator, VS Code theming";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
