# Wallpapers of the Nothing theme rendered at build time: every still picture of `dirs` (PNG, JPEG, WebP; GIFs
# and videos are left alone) as an LED dot matrix, once per output at its native resolution:
#   $out/<name>/<output>.png   and   $out/index.tsv: <sha256 of the source>\t<name>\t<file name>
# wallpaper-menu uses a rendering when the chosen file has the same content (sha256) and the look in effect
# has the same key (passthru.key, also in nothing.json); anything else is rendered at runtime into ~/.cache.
# Each picture x output is a derivation of its own: a rebuild renders only what changed. The sources are only
# read: the originals stay where they are.
{
  lib,
  runCommand,
  dotmatrix,
  dirs,
  outputs,
  args,
  key,
}:
let
  exts = [
    "png"
    "jpg"
    "jpeg"
    "webp"
  ];
  parts = file: builtins.match "(.+)\\.([^.]+)" file;
  isStill =
    file: type:
    type == "regular" && !lib.hasPrefix "." file && parts file != null
    && lib.elem (lib.toLower (lib.last (parts file))) exts;
  # store-safe name: letters, digits and "_", anything else becomes "-"
  nameOf =
    file:
    let
      n = lib.concatStringsSep "-" (
        builtins.filter (p: builtins.isString p && p != "") (builtins.split "[^A-Za-z0-9_]+" (lib.head (parts file)))
      );
    in
    if n != "" then n else "wallpaper";
  pictures = lib.foldl' (
    found: dir:
    found
    // lib.mapAttrs' (
      file: _:
      lib.nameValuePair (nameOf file) {
        inherit file;
        src = builtins.path {
          path = dir + "/${file}";
          name = "${nameOf file}.${lib.toLower (lib.last (parts file))}";
        };
      }
    ) (lib.filterAttrs isStill (builtins.readDir dir))
  ) { } dirs;
  render =
    name: pic: output: size:
    runCommand "monolith-dotmatrix-${name}-${output}" { nativeBuildInputs = [ dotmatrix ]; } ''
      monolith-dotmatrix ${pic.src} -o $out/${output}.png --resolution ${toString size.width}x${toString size.height} ${lib.escapeShellArgs args}
    '';
in
runCommand "monolith-nothing-wallpapers"
  {
    passthru = { inherit key; };
  }
  ''
    mkdir -p $out
    : >$out/index.tsv
    ${lib.concatStrings (
      lib.mapAttrsToList (name: pic: ''
        mkdir -p $out/${name}
        ${lib.concatStrings (
          lib.mapAttrsToList (output: size: ''
            ln -s ${render name pic output size}/${output}.png $out/${name}/${output}.png
          '') outputs
        )}
        printf '%s\t%s\t%s\n' "$(sha256sum <${pic.src} | cut -d' ' -f1)" ${lib.escapeShellArg name} ${lib.escapeShellArg pic.file} >>$out/index.tsv
      '') pictures
    )}
  ''
