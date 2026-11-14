# Default applications on NixOS (programs.monolith.defaultApps): MIME type -> .desktop file, written by Home
# Manager to ~/.config/mimeapps.list (xdg.mimeApps). The apps are the optional group of nix/packages.nix
# (Loupe, mpv, Papers, LibreOffice, micro), plus Nautilus for folders and the browser for web links when it is
# known. Text files and shell scripts open in micro inside the terminal (editor: monolith-micro.desktop, made
# by home.nix).
# The names are nixpkgs' own: LibreOffice installs writer.desktop / calc.desktop / impress.desktop (no
# "libreoffice-" prefix, unlike Arch). Every entry is a mkDefault in home.nix, so one type can be changed with
# xdg.mimeApps.defaultApplications."image/png" = "gimp.desktop".
{
  # the browser's .desktop file, or null to leave web links alone
  browser ? null,
  # the text editor's .desktop file, or null to leave text files alone
  editor ? null,
}:
let
  for = app: types: builtins.listToAttrs (map (t: { name = t; value = app; }) types);

  images = map (t: "image/${t}") [
    "png"
    "jpeg"
    "gif"
    "webp"
    "bmp"
    "tiff"
    "svg+xml"
    "avif"
    "heic"
    "heif"
    "jxl"
    "x-icon"
    "vnd.microsoft.icon"
    "x-tga"
    "x-portable-pixmap"
    "x-portable-graymap"
    "x-portable-bitmap"
    "x-portable-anymap"
    "x-exr"
    "x-qoi"
  ];

  videos = map (t: "video/${t}") [
    "mp4"
    "x-matroska"
    "webm"
    "quicktime"
    "x-msvideo"
    "x-flv"
    "x-ms-wmv"
    "mpeg"
    "ogg"
    "3gpp"
    "3gpp2"
    "mp2t"
    "x-m4v"
    "x-ogm+ogg"
    "vnd.avi"
  ];

  audio = map (t: "audio/${t}") [
    "mpeg"
    "mp4"
    "x-m4a"
    "aac"
    "flac"
    "x-flac"
    "ogg"
    "x-vorbis+ogg"
    "opus"
    "x-opus+ogg"
    "wav"
    "x-wav"
    "webm"
    "x-matroska"
    "x-ms-wma"
    "x-aiff"
    "x-ape"
    "x-mpegurl"
    "x-scpls"
  ];

  pdf = [
    "application/pdf"
    "application/x-pdf"
    "application/x-bzpdf"
    "application/x-gzpdf"
    "application/x-xzpdf"
    "application/postscript"
    "application/x-cbz"
    "application/vnd.comicbook+zip"
    "application/x-cbr"
    "application/vnd.comicbook-rar"
    "image/vnd.djvu"
    "image/vnd.djvu+multipage"
  ];

  writer = [
    "application/vnd.oasis.opendocument.text"
    "application/vnd.oasis.opendocument.text-template"
    "application/msword"
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
    "application/rtf"
    "text/rtf"
  ];

  calc = [
    "application/vnd.oasis.opendocument.spreadsheet"
    "application/vnd.oasis.opendocument.spreadsheet-template"
    "application/vnd.ms-excel"
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
    "text/csv"
  ];

  impress = [
    "application/vnd.oasis.opendocument.presentation"
    "application/vnd.oasis.opendocument.presentation-template"
    "application/vnd.ms-powerpoint"
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
    "application/vnd.openxmlformats-officedocument.presentationml.template"
  ];

  # text files, shell scripts and source code; text/plain also covers the types derived from it (.conf, .ini,
  # .bash, .nix, .lua...), since GIO falls back to the parent type's default. The source types below are the ones
  # micro.desktop and nvim.desktop declare themselves: a type an app names directly wins over the parent's
  # default, so without them a .py or .c would open through micro.desktop / nvim.desktop (Terminal=true)
  text = [
    "text/plain"
    "text/markdown"
    "text/x-markdown"
    "text/x-log"
    "text/x-shellscript"
    "application/x-shellscript"
    "application/x-fishscript"
    "application/json"
    "application/yaml"
    "application/x-yaml"
    "application/toml"
    "application/x-zerosize" # an empty file (Nautilus > New document)
    "application/xml"
    "text/css"
    "text/x-python"
    "text/x-c"
    "text/x-csrc"
    "text/x-chdr"
    "text/x-c++"
    "text/x-c++src"
    "text/x-c++hdr"
    "text/x-java"
    "text/x-diff"
    "text/x-makefile"
    "text/x-sql"
    "text/x-perl"
    "text/x-tex"
    "text/x-tcl"
    "text/x-pascal"
    "text/x-dsrc"
    "text/x-moc"
    "application/x-php"
  ];

  web = [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ];
in
for "org.gnome.Loupe.desktop" images
// for "mpv.desktop" (videos ++ audio)
// for "org.gnome.Papers.desktop" pdf
// for "writer.desktop" writer
// for "calc.desktop" calc
// for "impress.desktop" impress
// for "org.gnome.Nautilus.desktop" [ "inode/directory" ]
// (if editor == null then { } else for editor text)
// (if browser == null then { } else for browser web)
