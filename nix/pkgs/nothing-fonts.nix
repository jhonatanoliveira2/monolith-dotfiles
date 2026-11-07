# Fonts of the Nothing theme, from google/fonts at the revision nixpkgs' google-fonts uses (2026-03-13), one
# file each (the google-fonts package with `fonts = [...]` would download the whole repository):
#   Doto (dot matrix), Space Grotesk, Space Mono — SIL Open Font License 1.1.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  rev = "5174b3333331c966c38f4355d50b03ca1c1df2f9";
  get =
    path: hash:
    fetchurl {
      url = "https://raw.githubusercontent.com/google/fonts/${rev}/${path}";
      inherit hash;
    };
  files = {
    "Doto[ROND,wght].ttf" = get "ofl/doto/Doto%5BROND,wght%5D.ttf" "sha256-b0/n03hTuR3zaY2qhM3i2+HJaV2IyYbmUQE0kQM31CY=";
    "SpaceGrotesk[wght].ttf" = get "ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf" "sha256-rK1t4fyTQ29cDx9BN3Ue8E8a6jBj5wNlNZcP/PvXn3I=";
    "SpaceMono-Regular.ttf" = get "ofl/spacemono/SpaceMono-Regular.ttf" "sha256-lYN+GCuu6tqDNo93SNsoNX8KG3XGuE/3Blte35M8jhg=";
    "SpaceMono-Bold.ttf" = get "ofl/spacemono/SpaceMono-Bold.ttf" "sha256-QF5z1Br7flkG784gajJq9clW844lXzVCHCYOhh5ZnFk=";
    "SpaceMono-Italic.ttf" = get "ofl/spacemono/SpaceMono-Italic.ttf" "sha256-7KJkyGkKkf6DfRmmut8tiJYWEMTIqvyxllJhkqnyWMU=";
    "SpaceMono-BoldItalic.ttf" = get "ofl/spacemono/SpaceMono-BoldItalic.ttf" "sha256-zcyV7d7jEoealyhJTllfWRyxWfPydtebxYZz3sflcTg=";
  };
  licenses = {
    Doto = get "ofl/doto/OFL.txt" "sha256-Jqe1i9umzainjKbos3kdgBO4q8bV5lGfhBk4k67gICA=";
    SpaceGrotesk = get "ofl/spacegrotesk/OFL.txt" "sha256-VkzlZcNxxeW78oYAZWWnyapVqfVufKWNVuBdZJ3WGnI=";
    SpaceMono = get "ofl/spacemono/OFL.txt" "sha256-jk7kKyVT4eAVBOYcsNRtFIzYyeXqyqNiKn3y1PKVW58=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "monolith-nothing-fonts";
  version = "2026-03-13";
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    ${lib.concatStrings (
      lib.mapAttrsToList (name: src: ''
        install -Dm444 ${src} "$out/share/fonts/truetype/${name}"
      '') files
    )}
    ${lib.concatStrings (
      lib.mapAttrsToList (name: src: ''
        install -Dm444 ${src} "$out/share/licenses/monolith-nothing-fonts/${name}-OFL.txt"
      '') licenses
    )}
    runHook postInstall
  '';
  meta = {
    description = "Doto, Space Grotesk and Space Mono (Google Fonts) for the MONOLITH Nothing theme";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
