"""Create the original, deterministic periodic material data tile (stdlib only).

R is micro-height, G is roughness variation and B is machining grain. This is
linear material data, not a photographed or generated image with baked light.
"""
from pathlib import Path
import math
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "code/assets/materials_v1/micro_surface.png"
SIZE = 256


def channel(value: float) -> int:
    return round(max(0.0, min(1.0, value)) * 255)


def chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def build() -> None:
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)
        v = math.tau * y / SIZE
        for x in range(SIZE):
            u = math.tau * x / SIZE
            broad = math.sin(u * 3 + v * 5 + 0.7) * math.cos(u * 7 - v * 2 + 1.1)
            middle = math.sin(u * 17 - v * 11 + 2.4) * math.cos(u * 13 + v * 19 + 0.3)
            fine = math.sin(u * 47 + v * 31 + 0.6) * math.cos(u * 37 - v * 43 + 2.1)
            grain = math.sin(u * 53 + math.cos(v * 3) * 0.4)
            rows.extend((channel(0.5 + broad * 0.18 + middle * 0.12 + fine * 0.07),
                         channel(0.5 + broad * 0.20 - middle * 0.14 + fine * 0.08),
                         channel(0.5 + grain * 0.20 + fine * 0.08), 255))
    image = b"\x89PNG\r\n\x1a\n"
    image += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    image += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    image += chunk(b"IEND", b"")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(image)
    print(f"MATERIAL_MICRO size={SIZE} bytes={len(image)}")
    macro = bytearray()
    for y in range(SIZE):
        macro.append(0)
        v = math.tau * y / SIZE
        for x in range(SIZE):
            u = math.tau * x / SIZE
            height = 0.5 + 0.19 * math.sin(u * 2 + v * 3 + 0.8) * math.cos(u * 3 - v + 1.3)
            height += 0.11 * math.sin(u * 5 - v * 2 + 0.4) + 0.07 * math.cos(u + v * 4 + 2.2)
            deposit = 0.5 + 0.13 * math.sin(u + v * 2 + 2.1) * math.cos(u * 2 - v + 0.3)
            deposit += 0.10 * math.cos(u * 3 + v + 0.6) + 0.06 * math.sin(u - v * 4 + 1.7)
            seam = 0.5 + 0.23 * (0.7 * math.sin(u * 2 + v * 3 + 0.6) + 0.3 * math.cos(u * 3 - v + 0.2))
            macro.extend((channel(height), channel(deposit), channel(seam), 255))
    strata = b"\x89PNG\r\n\x1a\n"
    strata += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    strata += chunk(b"IDAT", zlib.compress(bytes(macro), 9))
    strata += chunk(b"IEND", b"")
    (OUTPUT.parent / "rock_strata.png").write_bytes(strata)
    print(f"ROCK_STRATA size={SIZE} bytes={len(strata)}")


if __name__ == "__main__":
    build()
