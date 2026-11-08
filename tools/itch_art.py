#!/usr/bin/env python3
"""The pictures for the game's itch.io page, from the game's own art:

  assets/itch_background.png  the page's background: a playfield that tiles
                              both ways, roads and invaders down both margins
  assets/itch_banner.png      the banner: the loading picture, dithered to the
                              C64's colours, with the game's name

    python3 tools/itch_art.py
"""
import os
import random
import sys

from PIL import Image, ImageEnhance

sys.path.insert(0, os.path.dirname(__file__))
import art  # noqa: E402
import c64gfx as g  # noqa: E402
import c64palette as pal  # noqa: E402
import font  # noqa: E402
import world  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")

# ------------------------------------------------------------------ background
COLS, ROWS = 30, 24             # 1920 x 1152: a pixel is 8 x 4, as wide as on the C64
LEFT = [(6, 0), (6, 8), (3, 8), (3, 10), (7, 10), (7, 19), (3, 19), (3, 21), (6, 21), (6, 23)]
RIGHT = [(29 - c, r) for c, r in LEFT]


def stage_part(k, letters="KP"):
    """the building of a stage: its pixels, and its size in cells"""
    st = world.STAGES[k]
    grid = world.carve_path(st.map, st.ground)
    if st.ground2:
        grid = world.carve_path(grid, st.ground2)
    cells = [(c, r) for r in range(14) for c in range(20) if st.map[r][c] in letters]
    c0, c1 = min(c for c, _ in cells), max(c for c, _ in cells)
    r0, r1 = min(r for _, r in cells), max(r for _, r in cells)
    cv = world.render_background(st, grid, True)
    fx, fy = st.flag
    cv.blit(art.FLAG_A, fx * 2, fy)
    rows = [row[c0 * 8:(c1 + 1) * 8] for row in cv.p[r0 * 12:(r1 + 1) * 12]]
    return rows, c1 - c0 + 1, r1 - r0 + 1


def background():
    world.MW, world.MH = COLS, ROWS
    empty = ["." * COLS] * ROWS
    grid = world.carve_path(world.carve_path(empty, LEFT), RIGHT)
    world.MW, world.MH = 20, 14
    parts = [(0, 1, 1), (0, 12, 7), (24, 1, 0), (24, 12, 6)]    # col, row, stage
    pics = [(c, r) + stage_part(k) for c, r, k in parts]
    world.MW, world.MH = COLS, ROWS

    cv = world.Canvas(COLS * 8, ROWS * 12, art.CH['g'])
    taken = {(c, r) for r in range(ROWS) for c in range(COLS) if grid[r][c] == '#'}
    for c, r, _, w, h in pics:
        taken |= {(c + i, r + j) for i in range(w) for j in range(h)}
    rnd = random.Random(8647)
    decor = {}
    for r in range(ROWS):
        for c in range(COLS):
            world.grass_cell(cv, c, r)
            if grid[r][c] == '#':
                world.path_cell(cv, grid, c, r)
            elif (c, r) not in taken and (c < 8 or c > 21) and rnd.random() < 0.28:
                decor[(c, r)] = rnd.choice("TTTYYRRSSJ")
    for (c, r), t in decor.items():
        x, y = c * 8, r * 12
        if t == 'T':
            cv.blit(world.TREE if (c + r) % 3 else world.TREE2, x, y)
        elif t == 'Y':
            cv.blit(world.CYPRESS, x, y)
        elif t == 'R':
            cv.blit(world.ROCK_A if (c + r) % 2 else world.ROCK_B, x, y)
        elif t == 'S':
            cv.blit(world.SHEEP if (c + r) % 2 else art.mirror(world.SHEEP), x, y)
        else:
            cv.blit(world.JAR, x, y)
    for c, r, rows, w, h in pics:
        for j, row in enumerate(rows):
            cv.p[r * 12 + j][c * 8:(c + w) * 8] = row
    # the invaders on the roads, the defenders beside them
    march = [(art.GUARD_A, 6, 2), (art.GUARD_B, 6, 5), (art.mirror(art.GUARD_A), 4, 8),
             (art.TANK_L_A, 5, 10), (art.TANK_V_A, 7, 13), (art.GUARD_A, 7, 16),
             (art.mirror(art.TANK_L_B), 5, 19), (art.GUARD_B, 4, 21), (art.TANK_V_B, 6, 22)]
    for rows, c, r in march:
        cv.blit(rows, c * 8, r * 12)
        cv.blit(art.mirror(rows), (29 - c) * 8, r * 12)
    for rows, c, r in ((art.DRONE_A, 2, 11), (art.DRONE_B, 5, 1), (art.DRONE_A, 26, 11), (art.DRONE_B, 22, 23),
                       (art.DRONE_A, 1, 23), (art.DRONE_B, 28, 0)):
        cv.blit(rows, c * 8, r * 12)
    for rows, c, r in ((art.CRETAN, 5, 7), (art.YIAYIA, 5, 14), (art.BRIDE, 2, 18), (art.PSSSST, 8, 12),
                       (art.BAKER, 7, 3), (art.LYRA, 22, 3), (art.CAULDRON, 21, 12), (art.CRETAN, 23, 13),
                       (art.YIAYIA, 27, 9), (art.BRIDE, 24, 7)):
        cv.blit(rows, c * 8, r * 12)
    im = Image.new("RGB", (COLS * 8, ROWS * 12))
    im.putdata([pal.RGB[g.PEN2C[p]] for row in cv.p for p in row])
    world.MW, world.MH = 20, 14
    return im.resize((COLS * 8 * 8, ROWS * 12 * 4), Image.NEAREST)


# ------------------------------------------------------------------ banner
SIZE = (960, 402)
PIXEL = 3                       # the picture's pixels, square
TOP = 20                        # the first line of the scene it shows
BANDS = [g.WHITE, g.WHITE, g.YELLOW, g.YELLOW, g.LIGHT_RED, g.LIGHT_RED]


def letters(px, text, x0, y0, bw, bh, colours, outline):
    """the game's font: blocks of bw x bh, an outline of `outline` around them"""
    w = px.width if hasattr(px, "width") else None
    d = Image.new("RGBA", (w, px.height), (0, 0, 0, 0))
    black = (0, 0, 0, 255)
    for phase in (0, 1):
        for k, ch in enumerate(text):
            for j, bits in enumerate(font.glyph_rows(font.glyph_index(ch))):
                for i in range(3):
                    if not bits & (4 >> i):
                        continue
                    x, y = x0 + k * 4 * bw + i * bw, y0 + j * bh
                    if phase == 0:
                        d.paste(black, (x - outline, y - outline, x + bw + outline, y + bh + outline + outline))
                    else:
                        d.paste(tuple(pal.RGB[colours[j]]) + (255,), (x, y, x + bw, y + bh))
    px.paste(d, (0, 0), d)


def text_width(text, bw):
    return (len(text) * 4 - 1) * bw


def banner():
    w, h = SIZE[0] // PIXEL, SIZE[1] // PIXEL
    src = Image.open(os.path.join(ASSETS, "vrouves.jpeg")).convert("RGB")
    src = ImageEnhance.Color(src).enhance(1.25)
    src = src.resize((w, src.height * w // src.width), Image.LANCZOS).crop((0, TOP, w, TOP + h))
    # by kind of colour, or the C64's greenish yellow turns the skin green, and
    # its light green the sky: warm colours from the warm inks, cool ones from
    # the inks without green
    warm = (g.RED, g.ORANGE, g.BROWN, g.LIGHT_RED, g.WHITE, g.LIGHT_GREY, g.BLACK, g.DARK_GREY)
    cool = tuple(c for c in range(16) if c not in (g.GREEN, g.LIGHT_GREEN, g.YELLOW))

    def ink(p):
        r, gr, b = p
        if r > 180 and gr > 170 and b < 90:         # a true yellow: the sun, the drone
            inks = range(16)
        elif r > gr + 8 and gr > b:
            inks = warm
        elif b >= gr:
            inks = cool
        else:
            inks = range(16)
        return min((sum((u - v) ** 2 for u, v in zip(p, pal.RGB[c])), c) for c in inks)[1]
    raw = src.tobytes()
    im = Image.new("RGB", (w, h))
    im.frombytes(bytes(v for i in range(0, len(raw), 3) for v in pal.RGB[ink(tuple(raw[i:i + 3]))]))
    im = im.resize(SIZE, Image.NEAREST)
    name = "LET'S GO FOR VROUVES"
    letters(im, name, (SIZE[0] - text_width(name, 11)) // 2, 14, 11, 8, BANDS, 5)
    sub = "ΠΑΜΕ ΓΙΑ ΒΡΟΥΒΕΣ - COMMODORE 64"
    letters(im, sub, (SIZE[0] - text_width(sub, 5)) // 2, 74, 5, 4, [g.WHITE] * 6, 3)
    return im


def main():
    background().save(os.path.join(ASSETS, "itch_background.png"), optimize=True)
    banner().save(os.path.join(ASSETS, "itch_banner.png"), optimize=True)


if __name__ == "__main__":
    main()
