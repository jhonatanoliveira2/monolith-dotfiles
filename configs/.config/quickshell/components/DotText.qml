import QtQuick
import "../core"

// Dot-matrix numbers / headings (Doto) for the Nothing theme; display sizes only (>= ~18 px). Without the
// theme (or the font) it is the shell's usual text.
Text {
    color: Theme.white
    font.family: Theme.fontDot
    font.pixelSize: 28
    font.weight: Nothing.hasDot && Theme.nothing ? Font.Black : Font.Bold
    verticalAlignment: Text.AlignVCenter
}
