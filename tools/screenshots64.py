#!/usr/bin/env python3
"""The manual's pictures (docs/img/*.png) and docs/screenshots.png, from a
headless VICE (make shots)."""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tests"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from game import Vice, start_game, press, frames, build, set_funds  # noqa: E402
import art  # noqa: E402
import c64gfx as g  # noqa: E402
import world  # noqa: E402

IMG = os.path.join(ROOT, "docs", "img")


def save(vm, name):
    vm.screenshot(os.path.join(IMG, name))
    print("screenshot", name)


def defence(stage, n=9):
    """grass cells beside the road, spread along it"""
    st = world.STAGES[stage]
    grid = world.carve_path(st.map, st.ground)
    cells = []
    for r in range(world.MH):
        for c in range(world.MW):
            if grid[r][c] != '.':
                continue
            near = sum(1 for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1))
                       if 0 <= c + dc < world.MW and 0 <= r + dr < world.MH and grid[r + dr][c + dc] == '#')
            if near:
                cells.append((near, (c * 7 + r * 13) % 11, c, r))
    cells.sort(reverse=True)
    picked = []
    for _, _, c, r in cells:
        if all(abs(c - pc) + abs(r - pr) > 2 for pc, pr in picked):
            picked.append((c, r))
        if len(picked) == n:
            break
    return picked


def battle(vm, stage, lang=0):
    set_funds(vm, 3000)
    vm.poke("unlock", 0x3f)
    kinds = [1, 3, 2, 6, 4, 5, 1, 3, 6]
    for k, (c, r) in zip(kinds, defence(stage)):
        build(vm, k, c, r)
    vm.poke("wave_num", 6)
    press(vm, "N")
    if lang:
        press(vm, "L")
    frames(vm, 420)


def icons():
    figs = [("cretan", art.CRETAN), ("yiayia", art.YIAYIA), ("bride", art.BRIDE), ("psssst", art.PSSSST),
            ("cauldron", art.CAULDRON), ("baker", art.BAKER), ("drone", art.DRONE_A), ("guard", art.GUARD_A),
            ("tank", art.TANK_V_A)]
    for name, rows in figs:
        cv = world.Canvas(12, 16, art.CH['g'])
        cv.blit(rows, 2, 2)
        img = [[g.PEN2C[p] for p in row] for row in cv.p]
        _, _, _, shown = g.quantize(img)
        g.save_png(shown, os.path.join(IMG, name + ".png"), 8, 4)


def main():
    os.makedirs(IMG, exist_ok=True)
    icons()
    with Vice() as vm:
        vm.run_to("title_frame", 3, timeout=120)
        save(vm, "title_en.png")
        press(vm, "L", at="title_frame")
        save(vm, "title_gr.png")
    for stage in range(7):
        with Vice() as vm:
            start_game(vm, stage)
            battle(vm, stage)
            save(vm, "stage%d.png" % (stage + 1))
            if stage == 0:
                save(vm, "game_en.png")
                press(vm, "L")
                save(vm, "game_gr.png")
    shots = [Image.open(os.path.join(IMG, n)) for n in
             ("title_en.png", "stage1.png", "stage3.png", "stage6.png", "stage7.png", "title_gr.png")]
    w, h = shots[0].size
    sheet = Image.new("RGB", (w * 3, h * 2))
    for i, im in enumerate(shots):
        sheet.paste(im, ((i % 3) * w, (i // 3) * h))
    sheet.resize((w * 3 // 2, h)).save(os.path.join(ROOT, "docs", "screenshots.png"))
    print("docs/screenshots.png")


if __name__ == "__main__":
    main()
