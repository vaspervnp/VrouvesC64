"""A small LZ77 packer for src/lz.asm (lz_unpack), with an optimal parse.

The stream is a run of tokens:
    $00-$7f  n+1 literal bytes follow
    $80-$bf  a copy of n-$7e bytes (2-65) from 'offset' bytes back in the
             output; offset - 1 follows (1-256)
    $c0-$fe  a copy of n-$be bytes (2-64); the offset follows, low byte first
             (1-65535)
    $ff      the end
"""


def pack(data):
    data = bytes(data)
    n = len(data)
    heads = {}
    matches = [()] * n
    for i in range(n - 1):
        near_len = far_len = 0
        near_off = far_off = 0
        key = data[i:i + 2]
        for j in reversed(heads.get(key, [])[-400:]):
            ln = 2
            while ln < 65 and i + ln < n and data[j + ln] == data[i + ln]:
                ln += 1
            off = i - j
            if off <= 256 and ln > near_len:
                near_len, near_off = ln, off
            if ln > far_len:
                far_len, far_off = ln, off
        found = []
        if near_len:
            found.append((near_len, near_off, 2))
        if far_len > near_len and far_off < 65536:
            found.append((min(far_len, 64), far_off, 3))
        matches[i] = found
        heads.setdefault(key, []).append(i)
    # from the end: the cheapest way on from each byte
    cost = [0] * (n + 1)
    run = [0] * (n + 1)
    choice = [None] * n
    for i in range(n - 1, -1, -1):
        r = run[i + 1]
        best = cost[i + 1] + 1 + (0 if 0 < r < 128 else 1)
        how, how_run = None, 1 if not 0 < r < 128 else r + 1
        for ln, off, size in matches[i]:
            for k in range(2, ln + 1):
                c = size + cost[i + k]
                if c < best:
                    best, how, how_run = c, (k, off, size), 0
        cost[i], choice[i], run[i] = best, how, how_run
    out = bytearray()
    lit = bytearray()

    def flush():
        nonlocal lit
        while lit:
            chunk = lit[:128]
            out.append(len(chunk) - 1)
            out.extend(chunk)
            lit = lit[128:]

    i = 0
    while i < n:
        if choice[i] is None:
            lit.append(data[i])
            i += 1
            continue
        flush()
        ln, off, size = choice[i]
        if size == 2:
            out += bytes([0x7E + ln, off - 1])
        else:
            out += bytes([0xBE + ln, off & 255, off >> 8])
        i += ln
    flush()
    out.append(0xFF)
    return bytes(out)


def unpack(stream):
    out = bytearray()
    i = 0
    while True:
        t = stream[i]
        i += 1
        if t == 0xFF:
            return bytes(out)
        if t < 0x80:
            out += stream[i:i + t + 1]
            i += t + 1
            continue
        if t < 0xC0:
            ln, off = t - 0x7E, stream[i] + 1
            i += 1
        else:
            ln, off = t - 0xBE, stream[i] | stream[i + 1] << 8
            i += 2
        for _ in range(ln):
            out.append(out[-off])


if __name__ == "__main__":
    import random
    for trial in range(100):
        d = bytes(random.choice(b"aab") for _ in range(random.randint(0, 1500)))
        assert unpack(pack(d)) == d
    print("ok")
