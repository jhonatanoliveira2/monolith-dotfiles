#!/usr/bin/env python3
# monolith-cava: cava in the MONOLITH Nothing theme. cava itself analyses the audio (raw ASCII output, one value
# per bar); this draws every bar as a column of LEDs in the terminal: lit ones white, fading to grey towards
# the top, unlit ones dark, and a peak LED that falls back slowly. q / Esc / Ctrl+C quits; resizing the
# terminal restarts cava with the new number of bars.
#
#   monolith-cava [--fps 30] [--fifo PATH]      (--fifo: read 44.1 kHz 16-bit audio from a FIFO, for tests)

import argparse
import os
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import termios
import tty

LIT = ["\x1b[38;5;255m", "\x1b[38;5;252m", "\x1b[38;5;249m", "\x1b[38;5;246m"]   # bottom .. top of a bar
PEAK = "\x1b[38;5;244m"
OFF = "\x1b[38;5;236m"
DOT, OFF_DOT = "●", "·"


def config(bars, rows, fps, fifo):
    src = (f"method = fifo\nsource = {fifo}\nsample_rate = 44100\nsample_bits = 16\n" if fifo
           else "method = pipewire\nsource = auto\n")
    return f"""[general]
bars = {bars}
framerate = {fps}
sleep_timer = 0
[input]
{src}[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = {rows}
bar_delimiter = 59
frame_delimiter = 10
channels = mono
[smoothing]
noise_reduction = 77
monstercat = 1
"""


def main():
    p = argparse.ArgumentParser(prog="monolith-cava", description="cava drawn as LEDs (MONOLITH Nothing theme)")
    p.add_argument("--fps", type=int, default=30)
    p.add_argument("--fifo", help="audio FIFO instead of PipeWire (tests)")
    a = p.parse_args()
    if not sys.stdout.isatty():
        print("monolith-cava: needs a terminal", file=sys.stderr)
        return 1

    tmp = tempfile.NamedTemporaryFile("w", prefix="monolith-cava-", suffix=".conf", delete=False)
    tmp.close()
    out = sys.stdout
    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd) if sys.stdin.isatty() else None
    proc = None

    def start(cols, lines):
        nonlocal proc
        if proc:
            proc.terminate()
            proc.wait()
        bars, rows = max(1, cols // 2), max(2, lines - 1)
        with open(tmp.name, "w") as f:
            f.write(config(bars, rows, a.fps, a.fifo))
        proc = subprocess.Popen(["cava", "-p", tmp.name], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
        return bars, rows

    def quit_(*_):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, quit_)
    try:
        if saved:
            tty.setcbreak(fd)
        out.write("\x1b[?1049h\x1b[?25l\x1b[2J")
        size = shutil.get_terminal_size()
        bars, rows = start(size.columns, size.lines)
        peak = [0.0] * bars
        while True:
            r, _, _ = select.select([proc.stdout] + ([sys.stdin] if saved else []), [], [], 1)
            if sys.stdin in r:
                ch = os.read(fd, 1)
                if ch in (b"q", b"Q", b"\x1b", b"\x03"):
                    break
            if proc.stdout not in r:
                if proc.poll() is not None:
                    break
                continue
            line = proc.stdout.readline()
            if not line:
                break
            now = shutil.get_terminal_size()
            if (now.columns, now.lines) != (size.columns, size.lines):
                size = now
                bars, rows = start(size.columns, size.lines)
                peak = [0.0] * bars
                out.write("\x1b[2J")
                continue
            vals = [min(rows, int(v or 0)) for v in line.strip().split(";")[:bars]]
            vals += [0] * (bars - len(vals))
            for i, v in enumerate(vals):
                peak[i] = max(v, peak[i] - 0.35)
            buf = ["\x1b[H"]
            for row in range(rows, 0, -1):       # top line first; row 1 is the bottom
                cur = ""
                for i, v in enumerate(vals):
                    if row <= v:
                        col = LIT[min(len(LIT) - 1, (row - 1) * len(LIT) // max(1, rows))]
                        ch = DOT
                    elif row == int(peak[i] + 0.5) and peak[i] >= 1:
                        col, ch = PEAK, DOT
                    else:
                        col, ch = OFF, OFF_DOT
                    if col != cur:
                        buf.append(col)
                        cur = col
                    buf.append(ch + " ")
                buf.append("\x1b[0m\x1b[K\n" if row > 1 else "\x1b[0m\x1b[K")
            out.write("".join(buf))
            out.flush()
    except KeyboardInterrupt:
        pass
    finally:
        if proc and proc.poll() is None:
            proc.terminate()
        out.write("\x1b[0m\x1b[?25h\x1b[?1049l")
        out.flush()
        if saved:
            termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        os.unlink(tmp.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
