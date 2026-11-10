# Mark, wordmark and light-sweep frames rendered by branding/build.sh. The mark is the official NixOS snowflake
# from nixpkgs' nixos-icons (NixOS artwork, CC-BY 4.0), drawn in the Monolith style; nothing is vendored.
{
  lib,
  stdenvNoCC,
  bash,
  librsvg,
  imagemagick,
  makeFontsConf,
  jetbrains-mono,
  nixos-icons,
}:
stdenvNoCC.mkDerivation {
  pname = "monolith-branding";
  version = "1";
  src = lib.cleanSource ../../branding;
  nativeBuildInputs = [
    bash
    librsvg
    imagemagick
  ];
  # the wordmark is SVG text in JetBrains Mono: fontconfig only sees that font, so the result is reproducible
  FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ jetbrains-mono ]; };
  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    icons=${nixos-icons}/share/icons
    flake=$(find $icons -name 'nix-snowflake-white.svg' | head -n1)
    [ -n "$flake" ] || flake=$(find $icons -name 'nix-snowflake.svg' | head -n1)   # tinted to grey anyway
    [ -n "$flake" ] || { echo "nix-snowflake SVG not found in nixos-icons" >&2; exit 1; }
    bash ./build.sh branding $TMPDIR/out "$flake"
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/monolith
    cp -r $TMPDIR/out $out/share/monolith/branding
    # sources for the other derivations (Plymouth / GRUB templates and the build script)
    cp -r . $out/share/monolith/branding-src
    runHook postInstall
  '';
  passthru.dir = "share/monolith/branding";
  meta = {
    description = "MONOLITH boot identity for NixOS: snowflake mark, wordmark and animation frames";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
