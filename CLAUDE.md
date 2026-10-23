# CLAUDE.md — VrouvesC64

The Commodore 64 (PAL) port of LET'S GO FOR VROUVES. The game it ports is the Amstrad CPC
version in `../VrouvesCPC`; its README and `src/game.asm` are the reference for what the game
*is*: the rules here are the same, tick for tick. This file is about what is different, and why.

## What does not come over

| CPC | C64 |
|---|---|
| Two screens, dirty rectangles, a background copy, software sprites | One multicolour bitmap. Invaders, effects, cursor: hardware sprites through the multiplexer. Only cells change in the bitmap. |
| Drawing at 12.5 fps, logic at 25 Hz | Logic still at 25 Hz (`game_run`: a tick per two frames gone, at most two). Sprites and input every pass, up to 50 Hz. |
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
- Shots are bitmap bytes saved and restored (`shots.asm`). Anything that draws on the playfield
  during a pass must run between `shots_erase` and `shots_draw` (or call `shots_erase` first, as
  `redraw_tile` and the banner do).

## Sprites (`mux.asm`, `irq.asm`)

- Objects sorted by Y; each goes to the sprite free the longest, so the IRQ entries come in line
  order. A sprite is busy for 21 lines whatever it shows; reuse needs `REUSE_GAP` lines more.
- `mux_build` builds the list not on show and sets `dl_ready`; the frame IRQ swaps. Never build
  while `dl_ready` is set.

## Building and testing

`make` (disk and tape), `make test` (headless VICE through the binary monitor; `test_disk` uses
a true 1541 and is slow), `make shots` (the manual's pictures), `make data`, `make pictures`.
Tests drive the game with `test_keys` (a key code, `$ff` none) and stop at `frame_done` /
`title_frame`.
