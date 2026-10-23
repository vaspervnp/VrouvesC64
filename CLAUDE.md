# CLAUDE.md — VrouvesC64

The Commodore 64 (PAL) port of LET'S GO FOR VROUVES. The game it ports is the Amstrad CPC
version in `../VrouvesCPC`; its README and `src/game.asm` are the reference for what the game
*is*: the rules here are the same, tick for tick, but for one the user asked for: at most
`SYN_MAX` (3) defenders on the stage have a neighbour's bonus (a penalty is not limited), the ones
built first (`t_seq`); `all_damage` takes it off the others. This file is about what is different,
and why.

## What does not come over

| CPC | C64 |
|---|---|
| Two screens, dirty rectangles, a background copy, software sprites | One multicolour bitmap. Invaders, effects, cursor: hardware sprites through the multiplexer. Only cells change in the bitmap. |
| Drawing at 12.5 fps, logic at 25 Hz | The same: `game_run` takes a pass every `PASS_FRAMES` (4) frames, two ticks in it. The keys are read every frame between (`kbd_scan`). |
| Stages and title loaded from disk; code in screen tails | One PRG; every stage in memory (tiles deduplicated across stages). |
| AY player | The SID player of Sugar Byte (`src/sound.asm`, `tools/mkmusic64.py`, `music/*.txt`). |

## Memory (`src/main.asm`, `src/const.inc`, `src/vars.inc`)

- `$01 = $35`. Zero page `$02-$8f` only: **`$90-$3ff` belongs to the KERNAL** and must stay as it
  was, because `disk.asm` banks the KERNAL in to load the ending and to load/save the high scores.
- VIC bank 3: screen `$c000`, bitmap `$e000` (under the KERNAL), sprites `$d000` (under the I/O,
  copied at start with `$01 = $34`). Workspace `$c400-$cfff`. Code and data `$0801-$bfff`
  (asserted).
- Loading the ending overwrites `$c000-$c7d0`: screen RAM and the start of the workspace. Nothing
  there may need to survive it (the high score table lives in the PRG's data).

## The screen

- A multicolour cell: `$d021` (grass green, `BG_COLOUR`), screen RAM high/low nibble, colour RAM.
  Text uses `%01` for letters and `%10` behind them, never `$d021`.
- `compose.asm` draws a playfield cell from its tile(s), the defender and the flag, and picks the
  colours exactly as `tools/c64gfx.py` does; `tests/test_compose.py` checks them byte for byte.
  Keep the two in step.
- The banner owns playfield rows 9-11 while `ban_on`: `compose_cell` skips them.
- Shots, the objects `mux_build` found no sprite for (`ob_drop`) and the flag's other frame are
  drawn by `bitmap_draw` (`shots.asm`) a cell row (strip) at a time, each while the raster is away
  from it, the bytes under them kept in a ring of line records, a block per strip. Anything else
  that draws on the playfield must `strip_clear` its rows first (`compose_cell` does it; so does
  the banner).
- The flag's two frames are kept (`flag_cache`, after the playfield is drawn and when a tile under it
  changes); `flag_tick` only picks the frame.

## Sprites (`mux.asm`, `irq.asm`)

- `ob_pin` (the cursor) has sprite 0 to itself (in front of the others). The others: sorted by Y; each goes to the sprite free the longest, so the IRQ entries come in line
  order. A sprite is busy for 21 lines whatever it shows; reuse needs `REUSE_GAP` lines more.
- `mux_build` builds the list not on show and sets `dl_ready`; the frame IRQ swaps. Never build
  while `dl_ready` is set.

## Building and testing

`make` (disk and tape), `make test` (headless VICE through the binary monitor; `test_disk` uses
a true 1541 and is slow), `make shots` (the manual's pictures), `make data`, `make pictures`.
Tests drive the game with `test_keys` (a key code, `$ff` none) and stop at `frame_done` /
`title_frame`.
