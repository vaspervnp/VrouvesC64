"""The disk, with a real 1541 (true drive emulation): the boot file loads the
game, a high score is saved and read back on the next boot, the ending loads
after the last stage. Slow: run on its own (run_tests.py does)."""

import os
import shutil
import unittest

from game import Vice, K, NONE, press, frames, ROOT_BUILD

DISK = os.path.join(ROOT_BUILD, "test_disk.d64")
ARGS = ("-drive8type", "1541", "-drive8truedrive")


def boot(disk):
    vm = Vice(image=disk, extra_args=ARGS)
    vm.run_to("title_frame", 3, timeout=900)
    return vm


def start(vm):
    vm.poke("test_keys", K["SPACE"])
    vm.run_to("frame_done", 1, timeout=120)
    vm.poke("test_keys", NONE)
    vm.run_to("frame_done", 1)


class DiskTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        shutil.copy(os.path.join(ROOT_BUILD, "vrouves.d64"), DISK)

    def test_high_score_saved_and_ending(self):
        with boot(DISK) as vm:
            self.assertEqual(vm.peek8("hs_table"), 22)              # V, from the table built in
            vm.poke("difficulty", 2)                                # no lives
            start(vm)
            vm.poke("score", bytes([0x0F, 0x27]))                   # 9999
            press(vm, "N")
            frames(vm, 5)
            score = vm.peek16("score")
            vm.poke("hp", 0)
            vm.run_to("end_game", 1, timeout=60)
            vm.run_to("wait_frame", 50)
            press(vm, "SPACE", at="wait_frame", frames=2)
            vm.run_to("wait_frame", 20)                             # the name: B, A, A
            press(vm, "DOWN", at="wait_frame", frames=2)
            for key in ("SPACE", "SPACE", "SPACE"):
                press(vm, key, at="wait_frame", frames=2)
            vm.run_to("title_frame", 2, timeout=900)                # saved
            entry = [2, 1, 1, score & 255, score >> 8]
            self.assertEqual(list(vm.peek("hs_table", 5)), entry)
            # the last stage won: the ending from the disk
            vm.poke("start_stage", 6)
            start(vm)
            vm.poke("wave_num", 10)
            vm.poke("wave_state", 1)
            vm.poke("sp_left", 0)
            vm.poke("en_count", 0)
            vm.poke("e_type", bytes(16))
            vm.run_to("end_game", 1, timeout=60)
            vm.run_to("wait_frame", 50)
            press(vm, "SPACE", at="wait_frame", frames=2)
            want = open(os.path.join(ROOT_BUILD, "endbmp.prg"), "rb").read()[-8:]
            for _ in range(60):                                     # until it is all in
                vm.run_to("wait_frame", 50, timeout=300)
                if vm.peek(0xE000 + 7992, 8, bank="ram") == want and vm.peek8(0xd021) & 15 == \
                        open(os.path.join(ROOT_BUILD, "endscr.prg"), "rb").read()[-1]:
                    break
            vm.run_to("wait_frame", 10)
            vm.screenshot(os.path.join(ROOT_BUILD, "test_ending.png"))
            self.assertEqual(vm.peek(0xC000, 8, bank="ram"), open(os.path.join(ROOT_BUILD, "endscr.prg"), "rb").read()[2:10])
            self.assertEqual(vm.peek(0xE000, 8, bank="ram"), open(os.path.join(ROOT_BUILD, "endbmp.prg"), "rb").read()[2:10])
        with boot(DISK) as vm:                                      # read back
            self.assertEqual(list(vm.peek("hs_table", 5)), entry)


if __name__ == "__main__":
    unittest.main()
