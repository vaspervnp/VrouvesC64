; =============================================================================
; hiscore.asm - the high score table: 8 entries of a 3 letter name (glyph
; codes) and a score. It is read from the disk at the start (VR-HISCORE,
; disk.asm); after a game good enough for it the player enters a name and
; the table is written back.
; =============================================================================

HS_N            = 8

hs_table        = hs_default            ; (text.asm; the disk's replaces it)

hs_new          .byte $ff               ; the newest entry's place ($ff none)
hs_pos          .byte 0
hs_idx          .byte 0,0,0
hs_score        .word 0

; with the title on screen: a game just ended with a score for the table?
hs_check
        lda #$ff
        sta hs_new
        lda score
        sta hs_score
        lda score+1
        sta hs_score+1
        lda #0                          ; looked at once only
        sta score
        sta score+1
        lda hs_table+(HS_N-1)*5+3       ; better than the last one?
        cmp hs_score
        lda hs_table+(HS_N-1)*5+4
        sbc hs_score+1
        bcc +
        rts
+       jsr hs_name
        jsr hs_insert
        jsr hs_save
        lda #HS_PAGE
        sta tpage
        jmp title_page

; the name, three letters: up / down pick, fire / right next, left back
hs_name
        lda #0
        sta hs_pos
        sta hs_idx
        sta hs_idx+1
        sta hs_idx+2
        lda #0
        ldx #PAGE_ROW
        ldy #16
        jsr fill_rows
        jsr text_normal
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr set_colors
        lda #T_NEWHS
        ldy #6
        jsr print_id_centered
        jsr text_big
        ldx #15
        ldy #8
        jsr set_at
        lda hs_score
        sta num
        lda hs_score+1
        sta num+1
        lda #5
        jsr print_num
        jsr text_normal
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr set_colors
        lda #T_NAME
        ldy #12
        jsr print_id_centered
        ldx #COL_LBLUE
        ldy #COL_BLACK
        jsr set_colors
        lda #T_NAMEKEYS
        ldy #19
        jsr print_id_centered
_draw   jsr text_big                    ; the three letters, the one picked yellow
        ldx #0
-       stx t6
        txa
        asl a
        adc #17
        sta txt_col
        lda #14
        sta txt_row
        ldy #COL_WHITE
        cpx hs_pos
        bne +
        ldy #COL_YELLOW
+       sty txt_fg
        lda #COL_BLACK
        sta txt_bg
        ldy hs_idx,x
        lda name_chars,y
        jsr put_glyph
        ldx t6
        inx
        cpx #3
        bne -
        jsr text_normal
_l      jsr wait_frame
        jsr kbd_update
        lda #C_UP
        jsr key_hit
        bcs _up
        lda #J_UP
        jsr key_hit
        bcs _up
        lda #C_DOWN
        jsr key_hit
        bcs _dn
        lda #J_DOWN
        jsr key_hit
        bcs _dn
        lda #C_LEFT
        jsr key_hit
        bcs _lf
        lda #J_LEFT
        jsr key_hit
        bcs _lf
        lda #C_RIGHT
        jsr key_hit
        bcs _nx
        lda #J_RIGHT
        jsr key_hit
        bcs _nx
        jsr fire_hit
        bcc _l
_nx     lda #SFX_BUILD
        jsr sfx_play
        inc hs_pos
        lda hs_pos
        cmp #3
        bne _draw
        rts
_lf     lda hs_pos
        beq _l
        dec hs_pos
        jmp _draw
_up     ldx hs_pos
        dec hs_idx,x
        bpl _snd
        lda #NAME_NCHARS-1
        sta hs_idx,x
        bne _snd                        ; (always)
_dn     ldx hs_pos
        inc hs_idx,x
        lda hs_idx,x
        cmp #NAME_NCHARS
        bcc _snd
        lda #0
        sta hs_idx,x
_snd    lda #SFX_MOVE
        jsr sfx_play
        jmp _draw

; the new entry into the table, the ones below it down a place
hs_insert
        ldx #0                          ; its place: before the first lower score
        ldy #0
-       lda hs_table+3,y
        cmp hs_score
        lda hs_table+4,y
        sbc hs_score+1
        bcc _got                        ; lower than ours (a tie stays above)
        tya
        clc
        adc #5
        tay
        inx
        cpx #HS_N
        bne -
        rts
_got    stx hs_new
        sty t0                          ; its offset
        ldy #(HS_N-1)*5-1               ; move the ones from it on down by 5
-       cpy t0
        bcc +
        lda hs_table,y
        sta hs_table+5,y
        dey
        cpy #$ff
        bne -
+       ldy t0
        ldx #0
-       stx t1
        lda hs_idx,x
        tax
        lda name_chars,x
        sta hs_table,y
        iny
        ldx t1
        inx
        cpx #3
        bne -
        lda hs_score
        sta hs_table,y
        lda hs_score+1
        sta hs_table+1,y
        rts

; the title page with the table; the newest entry in yellow
hs_show
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr set_colors
        lda #T_HSHDR
        ldy #PAGE_ROW
        jsr print_id_centered
        ldx #0
_r      stx hs_place
        txa                             ; the row: 6 + 2 * place
        asl a
        adc #6
        sta txt_row
        lda #11
        sta txt_col
        ldy #COL_WHITE
        cpx hs_new
        bne +
        ldy #COL_YELLOW
+       sty txt_fg
        lda #COL_BLACK
        sta txt_bg
        inx
        stx num
        lda #0
        sta num+1
        lda #1
        jsr print_num
        lda #15
        sta txt_col
        lda hs_place                          ; the name
        asl a
        asl a
        adc hs_place
        sta hs_off
        tax
        lda hs_table,x
        jsr put_glyph
        ldx hs_off
        lda hs_table+1,x
        jsr put_glyph
        ldx hs_off
        lda hs_table+2,x
        jsr put_glyph
        lda #22
        sta txt_col
        ldx hs_off
        lda hs_table+3,x
        sta num
        lda hs_table+4,x
        sta num+1
        lda #5
        jsr print_num
        ldx hs_place
        inx
        cpx #HS_N
        bne _r
        rts

hs_place        .byte 0
hs_off          .byte 0
