#!/usr/bin/env python3
"""The cassette: build/tape/boot.prg, then turbo blocks -> build/vrouves.tap (TAP v1).

The boot file is written in the KERNAL's own format (LOAD at the normal
speed, ~20 s); the game follows in turbo for the loader in src/tapeboot.asm
(~1.5 minutes): a short pulse (216 cycles) a 0, a long one (432) a 1, most
significant bit first; pilot $aa, sync $a5 $5a, load address, end address,
entry, the bytes, an XOR checksum.

  mktap.py build/vrouves.tap build/tape/boot.prg VROUVES build/splash.bin@0x2000 \
      build/tape/vrouves.prg@<entry> build/endscr.prg build/endbmp.prg
"""
import struct
import sys

S, M, L = 0x30, 0x42, 0x56                    # the KERNAL's pulses (cycles / 8)
T0, T1 = 216 // 8, 432 // 8                   # the turbo's


def kernal_byte(b):
    out = [L, M]
    ones = 0
    for i in range(8):
        bit = b >> i & 1
        ones += bit
        out += [M, S] if bit else [S, M]
    out += [M, S] if ones % 2 == 0 else [S, M]   # odd parity
    return out


def kernal_block(data, leader):
    out = []
    for copy in (0, 1):
        out += [S] * (leader if copy == 0 else 0x4F)
        for k in range(9, 0, -1):
            out += kernal_byte(k | (0x80 if copy == 0 else 0))
        chk = 0
        for b in data:
            out += kernal_byte(b)
            chk ^= b
        out += kernal_byte(chk)
        out += [L, S]
    out += [S] * 0x4E
    return out


def pause(cycles):
    return [0] + list(struct.pack("<I", cycles)[:3])


def turbo(data, load, entry):
    end = load + len(data)
    stream = [0xAA] * 1500 + [0xA5, 0x5A]
    stream += [load & 255, load >> 8, end & 255, end >> 8, entry & 255, entry >> 8]
    chk = 0
    for b in data:
        chk ^= b
    stream += list(data) + [chk] + [0] * 8
    out = []
    for b in stream:
        for i in range(7, -1, -1):
            out.append(T1 if b >> i & 1 else T0)
    return out


def check_sync():
    """the loader looks for $a5 then $5a bit by bit: not inside the pilot"""
    bits = "".join(f"{b:08b}" for b in [0xAA] * 8 + [0xA5, 0x5A])
    first = bits.find(f"{0xA5:08b}{0x5A:08b}")
    assert first == 64, first
    assert bits.find(f"{0xA5:08b}") == 64


def main():
    """mktap.py out.tap boot.prg name block... : a block is file.prg[@entry]
    (its load address from the file) or file.bin@load (raw)"""
    out_path, boot_path, title, *blocks = sys.argv[1:]
    check_sync()
    boot = open(boot_path, "rb").read()
    bload = boot[0] | boot[1] << 8
    bdata = boot[2:]
    name = title.upper().encode().ljust(16, b" ")[:16]
    header = bytes([0x01, bload & 255, bload >> 8, (bload + len(bdata)) & 255, (bload + len(bdata)) >> 8]) + name
    header = header.ljust(192, b" ")
    pulses = kernal_block(header, 0x6A00) + pause(300000) + kernal_block(bdata, 0x1500) + pause(200000)
    for spec in blocks:
        path, _, at = spec.partition("@")
        data = open(path, "rb").read()
        if path.endswith(".prg"):
            load, data = data[0] | data[1] << 8, data[2:]
            entry = int(at, 0) if at else 0
        else:
            load, entry = int(at, 0), 0
        pulses += turbo(data, load, entry) + pause(500000)
    body = bytes(pulses)
    tap = b"C64-TAPE-RAW" + bytes([1, 0, 0, 0]) + struct.pack("<I", len(body)) + body
    open(out_path, "wb").write(tap)
    secs = sum(p * 8 if p else 0 for p in pulses) / 985248
    print(f"{out_path}: {len(tap)} bytes, about {secs:.0f} s of tape")


if __name__ == "__main__":
    main()
