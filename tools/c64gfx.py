"""The C64 side of the graphics: the CPC's 16 pens as C64 colours, a
multicolour cell (4 x 8 pixels, the background and three colours of its
own) chosen the way the game chooses it at run time (src/compose.asm), and
multicolour sprites.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import art  # noqa: E402
import c64palette as pal  # noqa: E402

BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW = range(8)
ORANGE, BROWN, LIGHT_RED, DARK_GREY, GREY, LIGHT_GREEN, LIGHT_BLUE, LIGHT_GREY = range(8, 16)

# CPC pen (art.CH letters) -> C64 colour
PEN_COLOUR = {
    'k': BLACK, 'g': GREEN, 'o': ORANGE, 'r': BROWN, 'e': GREY, 'W': WHITE,
    'B': BLUE, 'c': LIGHT_BLUE, 'y': YELLOW, 'R': RED, 'l': LIGHT_GREEN,
    's': LIGHT_RED, 't': CYAN, 'p': LIGHT_GREEN, 'h': BROWN, 'n': BLACK,
}
PEN2C = [0] * 16
for _ch, _pen in art.CH.items():
    PEN2C[_pen] = PEN_COLOUR[_ch]

# the playfield's background colour ($d021): grass
BG = GREEN


def luma(c):
    r, g, b = pal.RGB[c]
    return 0.299 * r + 0.587 * g + 0.114 * b


def dist(a, b):
    """How far two C64 colours look apart (the table DIST in the game)."""
    ra, ga, ba = pal.RGB[a]
    rb, gb, bb = pal.RGB[b]
    return int(min(255, (((ra - rb) * 3) ** 2 + ((ga - gb) * 4) ** 2 + ((ba - bb) * 2) ** 2) ** 0.5 / 4))


DIST = [[dist(a, b) for b in range(16)] for a in range(16)]


def choose(colours, bg=BG):
    """32 colours of a cell -> (c1, c2, c3, codes): the three most common
    colours other than bg (ties: the lower colour), every pixel's 2 bit code.
    Exactly what compose.asm does."""
    count = [0] * 16
    for c in colours:
        count[c] += 1
    count[bg] = 0
    picked = []
    for _ in range(3):
        best, n = 0, 0
        for c in range(16):
            if count[c] > n:
                best, n = c, count[c]
        if n == 0:
            break
        picked.append(best)
        count[best] = 0
    while len(picked) < 3:                  # (no pixel shows these)
        picked.append(BLACK)
    slots = [bg] + picked
    code = {}
    for c in set(colours):
        if c in slots:
            code[c] = slots.index(c)
        else:
            d = [DIST[c][s] for s in slots]
            code[c] = d.index(min(d))
    return picked[0], picked[1], picked[2], [code[c] for c in colours]


def cell_bytes(colours, bg=BG):
    """-> (8 bitmap bytes, screen byte, colour byte, the shown colours)"""
    c1, c2, c3, codes = choose(colours, bg)
    bmp = []
    for y in range(8):
        b = 0
        for x in range(4):
            b = b << 2 | codes[y * 4 + x]
        bmp.append(b)
    slots = [bg, c1, c2, c3]
    return bmp, c1 << 4 | c2, c3, [slots[k] for k in codes]


def quantize(img, bg=BG):
    """img: rows of C64 colours, w a multiple of 4, h of 8 -> (bitmap bytes in
    cell order, screen bytes, colour bytes, the picture as shown)"""
    h, w = len(img), len(img[0])
    bmp, scr, col = [], [], []
    shown = [[0] * w for _ in range(h)]
    for cy in range(h // 8):
        for cx in range(w // 4):
            px = [img[cy * 8 + y][cx * 4 + x] for y in range(8) for x in range(4)]
            b, s, c, sh = cell_bytes(px, bg)
            bmp += b
            scr.append(s)
            col.append(c)
            for y in range(8):
                for x in range(4):
                    shown[cy * 8 + y][cx * 4 + x] = sh[y * 4 + x]
    return bmp, scr, col, shown


def save_png(img, path, sx=4, sy=2):
    from PIL import Image
    h, w = len(img), len(img[0])
    im = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            c = img[y][x]
            im.putpixel((x, y), (255, 0, 255) if c < 0 else pal.RGB[c])
    im.resize((w * sx, h * sy), Image.NEAREST).save(path)


# ---------------------------------------------------------------- sprites
# multicolour sprites: %01 = $d025, %11 = $d026 (shared by all), %10 = the
# sprite's own colour
SPR_MC0 = BLACK
SPR_MC1 = LIGHT_GREY


def sprite(rows, own=None):
    """art rows (one letter a pixel, '.' clear, at most 12 x 21) -> (63 bytes,
    its own colour, the picture as shown)"""
    cols = [[-1 if ch == '.' else PEN_COLOUR[ch] for ch in r] for r in rows]
    used = [c for r in cols for c in r if c >= 0]
    if own is None:
        best = None
        for cand in range(16):
            err = sum(min(DIST[c][s] for s in (SPR_MC0, SPR_MC1, cand)) for c in used)
            if best is None or err < best[0]:
                best = (err, cand)
        own = best[1]
    slots = {1: SPR_MC0, 2: own, 3: SPR_MC1}
    data = bytearray(63)
    shown = []
    for y, r in enumerate(cols):
        line = []
        for x, c in enumerate(r):
            if c < 0:
                line.append(-1)
                continue
            k = min(slots, key=lambda s: DIST[c][slots[s]])
            data[y * 3 + x // 4] |= k << (6 - 2 * (x % 4))
            line.append(slots[k])
        shown.append(line)
    return bytes(data), own, shown
