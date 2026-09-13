#!/usr/bin/env python3
"""Extract classic Unreal UMOD data without running its installer."""
import argparse
from pathlib import Path
import struct


def unpack(source: Path, output: Path):
    data = source.read_bytes()
    if len(data) < 20:
        raise ValueError("Truncated UMOD")
    magic, directory, size, version, _crc = struct.unpack_from("<5I", data, len(data)-20)
    if magic != 0x9FE3C5A3 or size != len(data) or version != 1:
        raise ValueError("Unsupported or invalid UMOD header")
    if directory >= len(data)-20:
        raise ValueError("Invalid directory offset")
    pos = directory

    def index():
        nonlocal pos
        if pos >= len(data)-20:
            raise ValueError("Truncated compact index")
        first = data[pos]; pos += 1
        value, shift, more = first & 63, 6, first & 64
        for _ in range(4):
            if not more:
                break
            if pos >= len(data)-20:
                raise ValueError("Truncated compact index")
            b = data[pos]; pos += 1
            value |= (b & 127) << shift
            shift += 7
            more = b & 128
        if more or first & 128:
            raise ValueError("Invalid compact index")
        return value

    records = []
    seen = set()
    count = index()
    if count > 10000:
        raise ValueError("Excessive file count")
    for _ in range(count):
        n = index()
        if not 1 <= n <= 4096 or pos+n+12 > len(data)-20:
            raise ValueError("Invalid file record")
        raw = data[pos:pos+n]; pos += n
        if raw[-1] != 0:
            raise ValueError("Unterminated filename")
        name = raw[:-1].decode("cp1252").replace("\\", "/")
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or ":" in name:
            raise ValueError("Unsafe filename")
        offset, length, flags = struct.unpack_from("<3I", data, pos); pos += 12
        if offset+length > directory:
            raise ValueError("File overlaps directory")
        dest = output/path
        if not dest.resolve().is_relative_to(output.resolve()) or dest.exists() or dest in seen:
            raise ValueError("Output escapes destination or already exists")
        seen.add(dest)
        records.append((dest, offset, length, flags))
    for dest, offset, length, _flags in records:
        dest.parent.mkdir(parents=True, exist_ok=True)
        with dest.open("xb") as stream:
            stream.write(data[offset:offset+length])
        print(f"{dest}: {length} bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    unpack(args.source, args.output)
