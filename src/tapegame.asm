; =============================================================================
; tapegame.asm - the cassette version's instead of disk.asm: the high scores
; stay in memory for as long as the C64 is on, and the ending is the next
; two blocks on the tape (leave it running after the game has loaded). After
; it the C64 starts again, as the CPC does at the end of its tape.
; =============================================================================

hs_load
hs_save
        rts

ending_show
        jsr wait_frame
        jsr shots_erase
        lda #0
        sta ob_n
        jsr mux_build_wait
        jsr wait_frame
        lda #T_LOADING
        ldx #$ff
        jsr banner_show
        sei
        lda #0
        sta VIC_IRQ_MASK
        sta VIC_SPR_ENA
        lda #1
        sta VIC_IRQ
        lda #0                          ; the SID quiet
        sta SID+4
        sta SID+11
        sta SID+18
-       jsr tape_load                   ; screen and colour RAM, bg ($c000)
        bcs -
-       jsr tape_load                   ; the bitmap ($e000)
        bcs -
        ldx #0                          ; the colour RAM
-       lda SCREEN+1000,x
        sta $d800,x
        lda SCREEN+1000+250,x
        sta $d800+250,x
        lda SCREEN+1000+500,x
        sta $d800+500,x
        lda SCREEN+1000+750,x
        sta $d800+750,x
        inx
        cpx #250
        bne -
        lda SCREEN+2000
        sta VIC_BG0
        lda #1
        sta VIC_IRQ
        sta VIC_IRQ_MASK
        cli
        lda #TUNE_MENU
        sta snd_want
-       jsr wait_frame
        jsr kbd_update
        jsr fire_hit
        bcc -
        sei                             ; the C64 starts again
        lda #$37
        sta $01
        jmp ($fffc)

        .include "tape.asm"
