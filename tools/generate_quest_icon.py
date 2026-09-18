#!/usr/bin/env python3
"""Generate Media/QuestAvailable.tga, a yellow quest-start bang icon."""

from __future__ import annotations

from pathlib import Path


SIZE = 64


def _draw_bang() -> list[list[tuple[int, int, int, int]]]:
    """Return bottom-up rows of BGRA pixels (TGA native order)."""
    pixels = [[(0, 0, 0, 0) for _ in range(SIZE)] for _ in range(SIZE)]
    # Classic-style yellow bang with a dark outline.
    yellow = (40, 200, 255, 255)  # B, G, R, A
    outline = (0, 20, 20, 255)

    def fill_rect(x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int, int]) -> None:
        for y in range(y0, y1):
            for x in range(x0, x1):
                if 0 <= x < SIZE and 0 <= y < SIZE:
                    pixels[y][x] = color

    # Stem outline then fill (top-down coordinates, converted later).
    fill_rect(26, 6, 38, 44, outline)
    fill_rect(28, 8, 36, 42, yellow)
    # Dot
    fill_rect(26, 48, 38, 60, outline)
    fill_rect(28, 50, 36, 58, yellow)
    return pixels


def write_tga(path: Path) -> None:
    pixels = _draw_bang()
    header = bytearray(18)
    header[2] = 2  # uncompressed true-color
    header[12] = SIZE & 0xFF
    header[13] = (SIZE >> 8) & 0xFF
    header[14] = SIZE & 0xFF
    header[15] = (SIZE >> 8) & 0xFF
    header[16] = 32
    header[17] = 0x08  # 8-bit alpha, origin bottom-left
    body = bytearray()
    # TGA is bottom-up: row 0 is the bottom of the image.
    for y in range(SIZE - 1, -1, -1):
        for x in range(SIZE):
            b, g, r, a = pixels[y][x]
            body.extend((b, g, r, a))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(header) + bytes(body))


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dest = root / "Media" / "QuestAvailable.tga"
    write_tga(dest)
    print(f"Wrote {dest}")


if __name__ == "__main__":
    main()
