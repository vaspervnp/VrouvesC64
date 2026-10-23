"""The cassette: the boot file at the KERNAL's speed, the loading picture and
the game in turbo, and the ending read from the tape after the last stage.
Slow: run on its own (run_tests.py does)."""

import os
import unittest

from game import Vice, K, NONE, press, ROOT_BUILD

TAP = os.path.join(ROOT_BUILD, "vrouves.tap")
LABELS = os.path.join(ROOT_BUILD, "tape", "labels.txt")


class TapeTest(unittest.TestCase):
    def test_tape(self):
        with Vice(image=TAP, labels=LABELS) as vm:
            vm.run_to("title_frame", 3, timeout=1500)
            self.assertEqual(vm.peek8(0xd011) & 0x20, 0x20)
            vm.poke("start_stage", 6)                       # the last stage, won at once
            vm.poke("test_keys", K["SPACE"])
            vm.run_to("frame_done", 1, timeout=120)
            vm.poke("test_keys", NONE)
            vm.run_to("frame_done", 1)
            vm.poke("wave_num", 10)
            vm.poke("wave_state", 1)
            vm.poke("sp_left", 0)
            vm.poke("en_count", 0)
            vm.poke("e_type", bytes(16))
            vm.run_to("end_game", 1, timeout=60)
            vm.run_to("wait_frame", 50)
            press(vm, "SPACE", at="wait_frame", frames=2)
            vm.run_to("wait_frame", 30, timeout=1500)       # the ending, from the tape
            want = open(os.path.join(ROOT_BUILD, "endbmp.prg"), "rb").read()
            self.assertEqual(vm.peek(0xE000, 64, bank="ram"), want[2:66])
            vm.screenshot(os.path.join(ROOT_BUILD, "test_tape_ending.png"))


if __name__ == "__main__":
    unittest.main()
