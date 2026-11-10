# GRUB theme directory (theme.txt + background + fonts). `resolution` should match boot.loader.grub.gfxmode*;
# GRUB stretches the background and positions everything in percent, so another mode still looks right.
{
  lib,
  stdenvNoCC,
  bash,
  librsvg,
  imagemagick,
  grub2,
  jetbrains-mono,
  branding,
  resolution ? "1920x1080",
  language ? "pt",
}:
stdenvNoCC.mkDerivation {
  pname = "grub-theme-monolith";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [
    bash
    librsvg
    imagemagick
    grub2
  ];
  installPhase = ''
    runHook preInstall
    export HOME=$TMPDIR
    fonts=${jetbrains-mono}/share/fonts
    regular=$(find $fonts -iname 'JetBrainsMono-Regular.ttf' | head -n1)
    bold=$(find $fonts -iname 'JetBrainsMono-Bold.ttf' | head -n1)
    [ -n "$regular" ] || regular=$(find $fonts -iname '*.ttf' | sort | head -n1)
    [ -n "$bold" ] || bold=$regular
    bash ${branding}/share/monolith/branding-src/build.sh grub ${branding}/${branding.dir} $out \
      ${lib.escapeShellArg resolution} ${lib.escapeShellArg language} "$regular" "$bold"
    runHook postInstall
  '';
  meta = {
    description = "MONOLITH GRUB theme";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
