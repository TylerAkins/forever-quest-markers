#!/usr/bin/env python3
"""Generate classic quest-start bang fallback textures."""

from __future__ import annotations

import math
from pathlib import Path


SIZE = 64
SAMPLES = 4  # 4x4 supersampling


def _sdf_circle(px: float, py: float, cx: float, cy: float, radius: float) -> float:
    return math.hypot(px - cx, py - cy) - radius


def _sdf_capsule(px: float, py: float, ax: float, ay: float, bx: float, by: float, radius: float) -> float:
    dx = bx - ax
    dy = by - ay
    length2 = dx * dx + dy * dy
    if length2 <= 0:
        return _sdf_circle(px, py, ax, ay, radius)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length2))
    return math.hypot(px - (ax + dx * t), py - (ay + dy * t)) - radius


def _shape_sdf(px: float, py: float) -> float:
    # Normalized 0-1 space. Stem + round dot, classic available-quest !.
    stem = _sdf_capsule(px, py, 0.50, 0.16, 0.50, 0.58, 0.105)
    dot = _sdf_circle(px, py, 0.50, 0.80, 0.105)
    return min(stem, dot)


def _sample_pixel(px: float, py: float, variant: str) -> tuple[int, int, int, int]:
    """Return BGRA for one sample in 0-1 space."""
    dist = _shape_sdf(px, py)
    outline = 0.055
    if dist > outline:
        return (0, 0, 0, 0)
    # Soft edge.
    if dist > 0:
        alpha = int(max(0.0, min(1.0, 1.0 - dist / outline)) * 255)
        return (8, 16, 24, alpha)
    # Fill: gold, repeatable blue, or attunement orange with a highlight.
    highlight = max(0.0, min(1.0, (0.55 - px) * 0.7 + (0.45 - py) * 0.5))
    if variant == "repeatable":
        r = int(35 + 45 * highlight)
        g = int(145 + 55 * highlight)
        b = int(235 + 20 * highlight)
    elif variant == "attunement":
        r = int(245 + 10 * highlight)
        g = int(65 + 60 * highlight)
        b = int(18 + 30 * highlight)
    else:
        r = 255
        g = int(196 + 44 * highlight)
        b = int(16 + 40 * highlight)
    inner = max(0.0, min(1.0, -dist / 0.04))
    outline_mix = 1.0 - inner
    r = int(r * inner + 24 * outline_mix)
    g = int(g * inner + 16 * outline_mix)
    b = int(b * inner + 8 * outline_mix)
    return (b, g, r, 255)


def _draw_bang(variant: str) -> list[list[tuple[int, int, int, int]]]:
    pixels = [[(0, 0, 0, 0) for _ in range(SIZE)] for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            acc_b = acc_g = acc_r = acc_a = 0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    px = (x + (sx + 0.5) / SAMPLES) / SIZE
                    py = (y + (sy + 0.5) / SAMPLES) / SIZE
                    b, g, r, a = _sample_pixel(px, py, variant)
                    acc_b += b
                    acc_g += g
                    acc_r += r
                    acc_a += a
            count = SAMPLES * SAMPLES
            pixels[y][x] = (
                acc_b // count,
                acc_g // count,
                acc_r // count,
                acc_a // count,
            )
    return pixels


def write_tga(path: Path, *, variant: str = "normal") -> None:
    if variant not in {"normal", "repeatable", "attunement"}:
        raise ValueError(f"unknown quest icon variant: {variant}")
    pixels = _draw_bang(variant)
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
    paths = (
        (root / "Media" / "QuestAvailable.tga", "normal"),
        (root / "Media" / "QuestRepeatable.tga", "repeatable"),
        (root / "Media" / "QuestAttunement.tga", "attunement"),
    )
    for path, variant in paths:
        write_tga(path, variant=variant)
        print(f"Wrote {path}")


if __name__ == "__main__":
    main()
