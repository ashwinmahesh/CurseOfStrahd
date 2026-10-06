#!/usr/bin/env python3
"""Joins same-sized PNG frames (from tools/capture/title_capture.tscn) into one animated PNG, reusing each frame's
compressed image data as is: python3 tools/capture/apng.py out.png 50 frame_000.png frame_001.png ... (50 = ms each)."""
import struct
import sys
import zlib


def chunks(data):
    pos = 8
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        yield kind, data[pos + 8:pos + 8 + length]
        pos += 12 + length


def chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)


def main():
    out, delay, frames = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
    first = open(frames[0], "rb").read()
    ihdr = next(b for k, b in chunks(first) if k == b"IHDR")
    width, height = struct.unpack(">II", ihdr[:8])
    parts = [first[:8], chunk(b"IHDR", ihdr), chunk(b"acTL", struct.pack(">II", len(frames), 0))]
    seq = 0
    for i, path in enumerate(frames):
        data = open(path, "rb").read()
        idats = [b for k, b in chunks(data) if k == b"IDAT"]
        parts.append(chunk(b"fcTL", struct.pack(">IIIIIHHBB", seq, width, height, 0, 0, delay, 1000, 0, 0)))
        seq += 1
        for body in idats:
            if i == 0:
                parts.append(chunk(b"IDAT", body))
            else:
                parts.append(chunk(b"fdAT", struct.pack(">I", seq) + body))
                seq += 1
    parts.append(chunk(b"IEND", b""))
    open(out, "wb").write(b"".join(parts))


if __name__ == "__main__":
    main()
