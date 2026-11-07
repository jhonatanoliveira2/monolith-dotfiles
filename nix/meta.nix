# Version and source revision of this flake, shared by the modules (nix.json, greeter, GRUB footer).
{ self, lib }:
let
  # MONOLITH_VERSION="x.y.z" in scripts/lib/common.sh (the same number the Arch installer reports)
  lines = lib.splitString "\n" (builtins.readFile ../scripts/lib/common.sh);
  matches = lib.filter (m: m != null) (map (builtins.match ''MONOLITH_VERSION="([^"]*)".*'') lines);
  date = self.lastModifiedDate or "19700101000000";
in
{
  version = if matches == [ ] then "0.0.0" else builtins.head (builtins.head matches);
  rev = self.rev or self.dirtyRev or "dirty";
  shortRev = self.shortRev or self.dirtyShortRev or "dirty";
  lastModified = "${lib.substring 0 4 date}-${lib.substring 4 2 date}-${lib.substring 6 2 date}";
  repo = "https://github.com/jhonatanoliveira2/monolith-dotfiles";
  branch = "feature/nothing-theme";
}
