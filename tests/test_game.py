"""The rules: building, selling, the waves, the sacks, winning, losing."""

import unittest

from game import Vice, start_game, press, frames, build, move_to, funds, set_funds, state


def win_now(vm):
    vm.poke("wave_num", 10)
    vm.poke("wave_state", 1)
    vm.poke("sp_left", 0)
    vm.poke("en_count", 0)
    vm.poke("e_type", bytes(16))


def to_end_banner(vm):
    vm.run_to("end_game", 1, timeout=60)
    vm.run_to("wait_frame", 50)


class GameTest(unittest.TestCase):
    def setUp(self):
        self.vm = Vice()
        start_game(self.vm)

    def tearDown(self):
        self.vm.close()

    def test_start(self):
        st = state(self.vm)
        self.assertEqual(funds(self.vm), 120)
        self.assertEqual((st["hp"], st["wave_num"], st["wave_state"], st["cd_sec"]), (100, 0, 0, 45))
        self.assertEqual(self.vm.peek8("unlock"), 0b001001)        # the cretan and psssst

    def test_build_and_sell(self):
        vm = self.vm
        build(vm, 1, 4, 2)                                          # a cretan on grass
        self.assertEqual(funds(vm), 120 - 35)
        self.assertEqual(vm.peek16("score"), 6)                     # its damage as points
        self.assertEqual(vm.peek8("t_type"), 1)
        cmap = vm.labels["cmap"]
        self.assertEqual(vm.peek8(cmap + 2 * 20 + 4), 0x80)
        press(vm, "S")
        self.assertEqual(funds(vm), 120 - 35 + 17)
        self.assertEqual(vm.peek16("score"), 0)
        self.assertEqual(vm.peek8(cmap + 2 * 20 + 4), 0)

    def test_three_bonuses_at_most(self):
        vm = self.vm
        set_funds(vm, 9000)
        vm.poke("unlock", 0x3f)
        cmap = vm.peek(vm.labels["cmap"], 20 * 14)
        grass = lambda c, r: 0 <= c < 20 and 0 <= r < 14 and cmap[r * 20 + c] == 0
        c, r = next((c, r) for r in range(1, 13) for c in range(1, 19)
                    if all(grass(c + dc, r + dr) for dc, dr in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1))))
        build(vm, 1, c, r)                                          # a cretan
        around = ((c - 1, r), (c + 1, r), (c, r - 1), (c, r + 1))
        for cc, rr in around:
            build(vm, 3, cc, rr)                                    # brides: +50% next to it
        self.assertEqual(list(vm.peek("t_type", 5)), [1, 3, 3, 3, 3])
        self.assertEqual(list(vm.peek("t_dmg", 5)), [6, 6, 6, 6, 4])   # the fourth: none
        move_to(vm, *around[0])
        press(vm, "S")                                              # one sold: the fourth has it
        self.assertEqual(list(vm.peek("t_dmg", 5))[2:], [6, 6, 6])

    def test_cannot_build(self):
        vm = self.vm
        move_to(vm, 2, 1)                                           # the road
        press(vm, "SPACE")
        self.assertEqual(funds(vm), 120)
        press(vm, "2")                                              # no yiayia in stage 1
        self.assertEqual(vm.peek8("sel_type"), 1)
        move_to(vm, 10, 2)                                          # a wall: only psssst
        press(vm, "SPACE")
        self.assertEqual(funds(vm), 120)
        press(vm, "4")
        press(vm, "SPACE")
        self.assertEqual(funds(vm), 120 - 80)
        self.assertEqual(vm.peek8(vm.labels["cmap"] + 2 * 20 + 10), 0xC0)

    def test_cursor_bounds(self):
        vm = self.vm
        move_to(vm, 0, 0)
        press(vm, "LEFT")
        press(vm, "UP")
        self.assertEqual((vm.peek8("cur_c"), vm.peek8("cur_r")), (0, 0))

    def test_call_wave_early(self):
        vm = self.vm
        cd = vm.peek8("cd_sec")
        press(vm, "N")
        st = state(vm)
        self.assertEqual((st["wave_num"], st["wave_state"]), (1, 1))
        self.assertEqual(funds(vm), 120 + cd // 2)
        self.assertEqual(vm.peek16("score"), cd)

    def test_invaders_come_and_hurt(self):
        vm = self.vm
        press(vm, "N")
        frames(vm, 200)
        self.assertGreater(vm.peek8("en_count"), 0)
        # a guard one step from the building: 8 HP off, two sacks gone (under 80, 60)
        vm.poke("hp", 61)
        vm.poke("e_type", bytes([2] + [0] * 15))
        vm.poke("en_count", 1)
        vm.poke("sp_left", 0)
        vm.poke("e_seg", 9)                     # the ground path's last segment
        vm.poke("e_rem", 1)
        vm.poke("e_acc", 15)
        vm.poke("e_slow", 0)
        frames(vm, 4)
        self.assertEqual(vm.peek8("hp"), 53)
        self.assertEqual(vm.peek8("sacks_gone"), 2)
        self.assertEqual(vm.peek8("en_count"), 0)

    def test_win_goes_on(self):
        vm = self.vm
        press(vm, "N")
        frames(vm, 10)
        win_now(vm)
        to_end_banner(vm)
        self.assertEqual(vm.peek8("game_over"), 1)
        vm.poke("test_keys", 60)                # SPACE: on
        vm.run_to("frame_done", 1, timeout=120)
        vm.poke("test_keys", 0xFF)
        vm.run_to("frame_done", 1)
        self.assertEqual(vm.peek8("stage"), 1)
        self.assertEqual(vm.peek8("unlock"), 0b001011)              # the yiayia joins

    def test_lose_with_lives(self):
        vm = self.vm
        lives = vm.peek8("lives")
        press(vm, "N")
        frames(vm, 10)
        score = vm.peek16("score")
        vm.poke("hp", 0)
        to_end_banner(vm)
        self.assertEqual(vm.peek8("game_over"), 2)
        vm.poke("test_keys", 60)                # SPACE: on
        vm.run_to("frame_done", 1, timeout=120)
        vm.poke("test_keys", 0xFF)
        vm.run_to("frame_done", 1)
        self.assertEqual(vm.peek8("lives"), lives - 1)
        self.assertEqual(vm.peek8("stage"), 0)
        self.assertEqual(funds(vm), 120)
        self.assertLessEqual(vm.peek16("score"), score)

    def test_pause_and_quit(self):
        vm = self.vm
        press(vm, "H")
        self.assertEqual(vm.peek8("paused"), 1)
        cd = (vm.peek8("cd_sec"), vm.peek8("cd_sub"))
        frames(vm, 50)
        self.assertEqual((vm.peek8("cd_sec"), vm.peek8("cd_sub")), cd)
        vm.poke("test_keys", 63)                # RUN/STOP while paused: the title
        vm.run_to("title_frame", 1, timeout=120)
        vm.poke("test_keys", 0xFF)

    def test_heavy_wave_keeps_pace(self):
        vm = self.vm
        set_funds(vm, 5000)
        vm.poke("unlock", 0x3f)
        for kind, c, r in [(1, 4, 2), (4, 6, 5), (2, 9, 3), (3, 13, 5), (5, 10, 8), (6, 12, 11),
                           (1, 16, 3), (3, 7, 8), (4, 14, 8), (1, 3, 6)]:
            build(vm, kind, c, r)
        vm.poke("wave_num", 8)
        press(vm, "N")
        frames(vm, 600)
        f0 = vm.peek8("frame")
        frames(vm, 100)
        elapsed = (vm.peek8("frame") - f0) & 255
        self.assertLess(elapsed, 250)          # at least 20 passes a second
        self.assertEqual(vm.peek8("game_over"), 0)

    def test_language(self):
        vm = self.vm
        press(vm, "L")
        self.assertEqual(vm.peek8("lang"), 1)
        press(vm, "L")
        self.assertEqual(vm.peek8("lang"), 0)


if __name__ == "__main__":
    unittest.main()
