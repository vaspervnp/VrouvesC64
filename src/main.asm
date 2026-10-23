; =============================================================================
; LET'S GO FOR VROUVES / ΠΑΜΕ ΓΙΑ ΒΡΟΥΒΕΣ - Commodore 64 (PAL)
; A tower defence game, the C64 version of the Amstrad CPC game.
;
;   64tass src/main.asm -> build/vrouves.prg (make)
;
; Memory:
;   $0002-$008f   zero page (vars.inc); $0090-$03ff is left to the KERNAL,
;                 which loads and saves for us (the high scores, the ending)
;   $0801-$bfff   BASIC stub, code, data
;   $c000-$c3ff   screen RAM (VIC bank 3)
;   $c400-$cfff   workspace (vars.inc)
;   $d000-$d7ff   sprite blocks, in the RAM under the I/O
;   $e000-$ff3f   the multicolour bitmap, in the RAM under the KERNAL
;   $fffa-$ffff   the vectors (the KERNAL is out: $01 = $35)
; =============================================================================

        .include "hw.inc"
        .include "const.inc"
        .include "vars.inc"

        .weak
DEBUG           = 0                     ; -D DEBUG=n: rich, at wave n, every defender
START_STAGE     = 1                     ; -D START_STAGE=n
TAPE            = 0                     ; -D TAPE=1: the cassette version
        .endweak

; ---------------------------------------------------------------------------
; BASIC stub: 10 SYS <start>
; ---------------------------------------------------------------------------
        * = $0801
        .word (+), 10
        .null $9e, format("%d", start)
+       .word 0

start
        sei
        cld
        ldx #$ff
        txs
        lda #$7f                        ; no CIA interrupts: the raster IRQ is the clock
        sta CIA1_ICR
        sta CIA2_ICR
        lda CIA1_ICR
        lda CIA2_ICR
        lda #0
        sta VIC_IRQ_MASK
        sta VIC_SPR_ENA
        sta VIC_CTRL1                   ; the screen off while it is set up
        lda #$35                        ; the ROMs out, the I/O in
        sta $01
        lda #<irq_frame
        sta IRQ_VEC
        lda #>irq_frame
        sta IRQ_VEC+1
        lda #<nmi
        sta NMI_VEC
        lda #>nmi
        sta NMI_VEC+1

        ldx #2                          ; the zero page, $02-$8f
        lda #0
-       sta 0,x
        inx
        cpx #$90
        bne -
        lda #<WORK                      ; the workspace
        sta ptr
        lda #>WORK
        sta ptr+1
        ldy #0
        tya
-       sta (ptr),y
        iny
        bne -
        inc ptr+1
        ldx ptr+1
        cpx #>SPRITES
        bne -

        lda #$34                        ; the sprites under the I/O
        sta $01
        ldx #0
-       .for i = 0, i < (NUM_SPRITES*64+255)/256, i += 1
        lda sprite_data+i*256,x
        sta SPRITES+i*256,x
        .endfor
        inx
        bne -
        lda #$35
        sta $01

        lda #$ff
        sta test_keys
        lda #$a5
        sta seed
        lda #$f3
        sta seed+1
        lda #1
        sta mus_on
        jsr video_init
        jsr sound_init
        lda #TUNE_MENU
        sta snd_want
        jsr irq_init
        cli
        jsr hs_load

main_title
        jsr title_screen
        lda frame                       ; the time the title took: a new game
        eor seed
        sta seed
        lda start_stage
_stage  sta stage
        jsr stage_load
_play   jsr game_run
        jsr retry                       ; lost with a life left: the stage again
        bcc _play
        lda game_over                   ; won: on to the next stage
        cmp #1
        bne main_title
        lda stage
        clc
        adc #1
        cmp #NUM_STAGES
        bcc _stage
        jsr ending_show                 ; all won: the feast at the school
        jmp main_title

nmi     rti

start_stage     .byte START_STAGE-1         ; (tests set it)

; after game_run: C set = on as before (won, quit, or lost with no life
; left); C clear = lost, a life gone, the same stage again
retry
        lda game_over
        cmp #2
        beq +
        lda score                       ; won (or quit): the score to go back to
        sta score_chk
        lda score+1
        sta score_chk+1
        sec
        rts
+       lda lives
        bne +
        sec
        rts
+       dec lives
        lda score_chk
        sta score
        lda score_chk+1
        sta score+1
        clc
        rts

; ---------------------------------------------------------------------------
        .include "irq.asm"
        .include "mux.asm"
        .include "input.asm"
        .include "video.asm"
        .include "text.asm"
        .include "compose.asm"
        .include "shots.asm"
        .include "game.asm"
        .include "hud.asm"
        .include "title.asm"
        .include "hiscore.asm"
        .if TAPE != 0
        .include "tapegame.asm"
        .else
        .include "disk.asm"
        .endif
        .include "lz.asm"
        .include "sound.asm"
code_end

; --- data ---------------------------------------------------------------------
        .include "data/gfx.asm"
        .include "data/stages.asm"
        .include "data/text.asm"
        .include "data/music.asm"
data_end
        .cerror data_end > SCREEN, "the program runs into the screen at $c000"
