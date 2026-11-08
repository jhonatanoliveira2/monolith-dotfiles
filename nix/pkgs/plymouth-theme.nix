# Plymouth "monolith" theme (script module). Installed paths point into this store path; the NixOS module
# copies the theme into the initrd (boot.plymouth.themePackages) so it also handles LUKS passwords.
{
  lib,
  stdenvNoCC,
  bash,
  jetbrains-mono,
  branding,
  # Nothing theme: a row of LEDs for the progress (monolith.nothingTheme.enable)
  nothing ? false,
}:
stdenvNoCC.mkDerivation {
  pname = "plymouth-theme-monolith";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ bash ];
  installPhase = ''
    runHook preInstall
    dir=$out/share/plymouth/themes/monolith
    NOTHING=${if nothing then "1" else "0"} bash ${branding}/share/monolith/branding-src/build.sh plymouth ${branding}/${branding.dir} $dir $dir
    # the font Plymouth renders prompts and messages with (boot.plymouth.font in the NixOS module)
    font=$(find ${jetbrains-mono}/share/fonts -iname 'JetBrainsMono-Regular.ttf' | head -n1)
    [ -n "$font" ] || font=$(find ${jetbrains-mono}/share/fonts -iname '*.ttf' | sort | head -n1)
    install -Dm444 "$font" $dir/font.ttf
    runHook postInstall
  '';
  passthru.font = "share/plymouth/themes/monolith/font.ttf";
  meta = {
    description = "MONOLITH Plymouth boot splash";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
