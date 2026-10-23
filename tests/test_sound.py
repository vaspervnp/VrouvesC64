"""The sound: the title's tune, the game's, the effects on voice 3."""

import unittest

from game import Vice, start_game, press, frames


class SoundTest(unittest.TestCase):
    def test_tunes_and_effects(self):
        with Vice() as vm:
            vm.run_to("title_frame", 10, timeout=120)
            self.assertEqual(vm.peek8("snd_tune"), vm.peek8("snd_want"))
            menu = vm.peek8("snd_tune")
            start_game(vm)
            frames(vm, 5)
            self.assertNotEqual(vm.peek8("snd_tune"), menu)          # the game's tune
            ticks = vm.peek8("snd_ticks")
            frames(vm, 10)
            self.assertNotEqual(vm.peek8("snd_ticks"), ticks)        # it plays
            press(vm, "SPACE")                                       # a cretan: the build effect
            self.assertEqual(vm.peek8("sfx_on"), 1)
            press(vm, "M")
            self.assertEqual(vm.peek8("mus_on"), 0)


if __name__ == "__main__":
    unittest.main()
