"""The playfield as compose.asm draws it is the one tools/c64gfx.py works
out, cell for cell: every stage, and with defenders on it."""

import os
import sys
import unittest

from game import Vice, start_game, build, set_funds, frames

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import art  # noqa: E402
import c64gfx as g  # noqa: E402
import world  # noqa: E402

TYPES = {1: art.CRETAN, 2: art.YIAYIA, 3: art.BRIDE, 4: art.PSSSST, 5: art.CAULDRON, 6: art.BAKER}


def expected(stage, towers=(), flag_b=False):
    st = world.STAGES[stage]
    grid = world.carve_path(st.map, st.ground)
    cv = world.render_background(st, grid, True)
    for kind, c, r in towers:
        cv.blit(TYPES[kind], c * 8, r * 12)
    fx, fy = st.flag
    cv.blit(art.FLAG_B if flag_b else art.FLAG_A, fx * 2, fy)
    img = [[g.PEN2C[p] for p in row] for row in cv.p]
    return g.quantize(img)


def actual(vm):
    bmp = vm.peek(0xE000 + 2 * 320, 21 * 320, bank="ram")
    scr = vm.peek(0xC000 + 2 * 40, 21 * 40, bank="ram")
    col = bytes(b & 15 for b in vm.peek(0xD800 + 2 * 40, 21 * 40, bank="io"))
    return bmp, scr, col


class ComposeTest(unittest.TestCase):
    def check(self, vm, stage, towers=(), skip_rows=()):
        bmp, scr, col, _ = expected(stage, towers, vm.peek8("flag_frame") == 1)
        abmp, ascr, acol = actual(vm)
        for cy in range(21):
            if cy in skip_rows:
                continue
            for cx in range(40):
                i = cy * 40 + cx
                where = "stage %d cell %d,%d" % (stage + 1, cx, cy)
                self.assertEqual(list(abmp[i * 8:i * 8 + 8]), bmp[i * 8:i * 8 + 8], where)
                self.assertEqual(ascr[i], scr[i], where)
                self.assertEqual(acol[i], col[i], where)

    def test_stages(self):
        for stage in range(7):
            with Vice() as vm:
                start_game(vm, stage)
                frames(vm, 2)
                # the banner on rows 9-11 at the start (stages 1-5)
                self.check(vm, stage, skip_rows=(9, 10, 11) if stage < 5 else ())

    def test_defenders(self):
        towers = [(1, 4, 2), (4, 6, 5), (2, 9, 3), (3, 13, 5), (5, 10, 8), (6, 12, 11), (4, 15, 2)]
        with Vice() as vm:
            start_game(vm)
            set_funds(vm, 3000)
            vm.poke("unlock", 0x3f)
            for kind, c, r in towers:
                build(vm, kind, c, r)
            frames(vm, 2)
            self.check(vm, 0, towers, skip_rows=(9, 10, 11))


if __name__ == "__main__":
    unittest.main()
