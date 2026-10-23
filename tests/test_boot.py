"""Boot: the title screen, the IRQ at 50 Hz, the memory and the VIC set-up."""

import unittest

from game import Vice, press


class BootTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.vm = Vice()
        cls.vm.run_to("title_frame", 3, timeout=120)

    @classmethod
    def tearDownClass(cls):
        cls.vm.close()

    def test_memory_config(self):
        self.assertEqual(self.vm.peek8(0x01) & 0x07, 0x05)     # the ROMs out, the I/O in

    def test_pal(self):
        width, height, *_ = self.vm.display()
        self.assertEqual(height, 312)

    def test_one_frame_per_irq(self):
        before = self.vm.peek8("frame")
        self.vm.run_to("title_frame", 50)
        self.assertEqual((self.vm.peek8("frame") - before) & 255, 50)

    def test_bitmap_mode(self):
        self.assertEqual(self.vm.peek8(0xd011) & 0x20, 0x20)
        self.assertEqual(self.vm.peek8(0xd016) & 0x10, 0x10)
        self.assertEqual(self.vm.peek8(0xd018) & 0xfe, 0x08)   # (bit 0 reads 1)
        self.assertEqual(self.vm.peek8(0xdd00) & 3, 0)           # bank 3

    def test_kernal_memory_untouched(self):
        # the KERNAL's vectors are as it left them: it can still load and save
        self.assertEqual(self.vm.peek16(0x0314), 0xEA31)

    def test_pages_and_language(self):
        for page in range(5):
            self.assertEqual(self.vm.peek8("tpage"), page)
            press(self.vm, "J_RIGHT", at="title_frame")
        self.assertEqual(self.vm.peek8("tpage"), 0)
        press(self.vm, "L", at="title_frame")
        self.assertEqual(self.vm.peek8("lang"), 1)
        press(self.vm, "L", at="title_frame")
        self.assertEqual(self.vm.peek8("lang"), 0)

    def test_difficulty(self):
        d = self.vm.peek8("difficulty")
        press(self.vm, "D", at="title_frame")
        self.assertEqual(self.vm.peek8("difficulty"), (d + 1) & 3)
        for _ in range(3):
            press(self.vm, "D", at="title_frame")
        self.assertEqual(self.vm.peek8("difficulty"), d)


if __name__ == "__main__":
    unittest.main()
