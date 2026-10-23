; =============================================================================
; tapeboot.asm - the tape's boot file (LOAD, RUN: the KERNAL loads it at its
; own speed). It moves the turbo loader up out of the way and reads the
; next blocks in turbo (tools/mktap.py): the loading picture, shown at once,
; then the game, on show over it as it loads; then it starts the game.
; =============================================================================

        .include "hw.inc"

LOADER          = $c800
PIC             = $2000                 ; the picture's block: bitmap, screen, colour, bg
PIC_BMP         = $e000
PIC_SCR         = $cc00

        * = $0801
        .word (+), 10
        .null $9e, format("%d", boot)
+       .word 0

boot
        sei
        ldx #0
-       lda loader_src,x
        sta LOADER,x
        lda loader_src+256,x
        sta LOADER+256,x
        inx
        bne -
        jmp LOADER

loader_src
        .logical LOADER
        lda #$0b                        ; blank until the picture is in
        sta VIC_CTRL1
        lda #0
        sta VIC_SPR_ENA
        sta VIC_IRQ_MASK
_pic    jsr tape_load                   ; the picture
        bcs _pic
        ldx #0
-       .for i = 0, i < 32, i += 1
        lda PIC+i*250,x
        sta PIC_BMP+i*250,x
        .endfor
        inx
        cpx #250
        beq +
        jmp -
+       ldx #0
-       .for i = 0, i < 4, i += 1
        lda PIC+8000+i*250,x
        sta PIC_SCR+i*250,x
        lda PIC+9000+i*250,x
        sta $d800+i*250,x
        .endfor
        inx
        cpx #250
        bne -
        lda PIC+10000
        sta VIC_BG0
        lda CIA2_PRA                    ; bank 3, screen $cc00, bitmap $e000
        and #$fc
        sta CIA2_PRA
        lda #$38
        sta VIC_MEM
        lda #$18
        sta VIC_CTRL2
        lda #$3b
        sta VIC_CTRL1
_game   jsr tape_load                   ; the game
        bcs _bad
        jmp (tape_head+4)
_bad    lda #2                          ; a red border: wind back a little, PLAY
        sta $d020
        jmp _game

        .include "tape.asm"
        .here
loader_end
        .cerror loader_end - loader_src > 512, "the loader is longer than two pages"
