# `nix run .#install`: the guided installer for the NixOS ISO (nix/install/monolith-install.sh). The template
# comes from this same revision; the ISO's own nixos-install / nixos-generate-config / nixos-enter are used
# (--suffix PATH keeps them first). MONOLITH_REV is the commit this installer was built from: the configuration it
# writes follows that same branch (or that commit), never the repository's default branch by accident.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  gnused,
  gnugrep,
  gawk,
  util-linux,
  parted,
  dosfstools,
  e2fsprogs,
  cryptsetup,
  systemd,
  iputils,
  nano,
  efibootmgr,
  gnutar,
  findutils,
  gitMinimal,
  rev ? "",
}:
let
  template = lib.cleanSource ../../templates/nixos;
in
stdenvNoCC.mkDerivation {
  pname = "monolith-install";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];
  installPhase = ''
    runHook preInstall
    install -Dm755 ${../install/monolith-install.sh} $out/bin/monolith-install
    patchShebangs --host $out/bin
    wrapProgram $out/bin/monolith-install \
      --set MONOLITH_TEMPLATE ${template} \
      ${lib.optionalString (rev != "") "--set MONOLITH_REV ${rev}"} \
      --suffix PATH : ${
        lib.makeBinPath [
          coreutils
          gnused
          gnugrep
          gawk
          util-linux
          parted
          dosfstools
          e2fsprogs
          cryptsetup
          systemd
          iputils
          nano
          efibootmgr
          gnutar
          findutils
          gitMinimal
        ]
      }
    runHook postInstall
  '';
  meta = {
    description = "Guided NixOS + MONOLITH installer for the NixOS installer ISO";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "monolith-install";
  };
}
