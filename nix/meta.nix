# Version and source revision of this flake, shared by the modules (nix.json, greeter, GRUB footer).
{ self, lib }:
let
  date = self.lastModifiedDate or "19700101000000";
in
{
  version = "0.1.0"; # MONOLITH version shown in Settings > System / Update
  rev = self.rev or self.dirtyRev or "dirty";
  shortRev = self.shortRev or self.dirtyShortRev or "dirty";
  lastModified = "${lib.substring 0 4 date}-${lib.substring 4 2 date}-${lib.substring 6 2 date}";
  repo = "https://github.com/jhonatanoliveira2/monolith-dotfiles";
  branch = "main";
}
