"""Driving the game in VICE: keys, the cursor, building, the state."""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from vice import Vice  # noqa: E402,F401

K = {"SPACE": 60, "RETURN": 1, "N": 39, "S": 13, "H": 29, "L": 42, "M": 36, "D": 18,
     "STOP": 63, "1": 56, "2": 59, "3": 8, "4": 11, "5": 16, "6": 19,
     "UP": 72, "DOWN": 73, "LEFT": 74, "RIGHT": 75, "FIRE": 68, "J_RIGHT": 67}
NONE = 0xFF
ROOT_BUILD = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build")


def press(vm, key, at="frame_done", frames=1):
    """the key down for a pass of the loop, then up for one"""
    vm.poke("test_keys", K[key] if isinstance(key, str) else key)
    vm.run_to(at, frames)
    vm.poke("test_keys", NONE)
    vm.run_to(at, 1)


def frames(vm, n, at="frame_done"):
    vm.run_to(at, n, timeout=600)


def start_game(vm, stage=None):
    """from the boot to the first stage's first frame"""
    vm.run_to("title_frame", 3, timeout=120)
    if stage is not None:
        vm.poke("start_stage", stage)
    vm.poke("test_keys", K["SPACE"])
    vm.run_to("frame_done", 1, timeout=120)
    vm.poke("test_keys", NONE)
    vm.run_to("frame_done", 1)


def cursor(vm):
    return vm.peek8("cur_c"), vm.peek8("cur_r")


def move_to(vm, c, r):
    """the cursor to (c, r), a step per press"""
    for _ in range(60):
        cc, rr = cursor(vm)
        if (cc, rr) == (c, r):
            return
        if cc < c:
            press(vm, "RIGHT")
        elif cc > c:
            press(vm, "LEFT")
        elif rr < r:
            press(vm, "DOWN")
        else:
            press(vm, "UP")
    raise AssertionError("the cursor did not get to %r" % ((c, r),))


def build(vm, kind, c, r):
    """defender kind (1-6) at (c, r)"""
    move_to(vm, c, r)
    press(vm, str(kind))
    press(vm, "SPACE")


def funds(vm):
    return vm.peek16("funds")


def set_funds(vm, n):
    vm.poke("funds", bytes([n & 255, n >> 8]))


def state(vm):
    return {k: vm.peek8(k) for k in ("wave_num", "wave_state", "hp", "en_count", "game_over", "cd_sec")}
