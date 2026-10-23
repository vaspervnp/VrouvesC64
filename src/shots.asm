; =============================================================================
; shots.asm - the defenders' shots, drawn straight into the bitmap (there are
; too many of them for the sprites): a small block in the brightest colour
; of the cell it is in, the bytes under it kept and put back before the next
; tick moves them. Everything else that draws on the playfield does so
; between shots_erase and shots_draw.
; =============================================================================

; the bitmap as it was under the shots
shots_erase
        ldx sv_n
        beq _none
-       dex
        lda sv_lo,x
        sta ptr
        lda sv_hi,x
        sta ptr+1
        lda sv_val,x
        ldy #0
        sta (ptr),y
        txa
        bne -
        stx sv_n
_none   rts

shots_draw
        lda #0
        sta sv_n
        ldx #MAX_PR-1
_shot   lda p_type,x
        beq _next
        stx iy
        tay
        lda shot_w-1,y
        sta sh_w
        lda shot_h-1,y
        sta sh_h
        lda p_x,x
        and #$fe
        sta sh_x
        lda p_y,x
        sta sh_line
-       lda sh_line
        cmp #PF_ROWS*8
        bcs _done
        lda sh_x
        jsr shot_pixels
        lda sh_w
        cmp #4
        bcc +
        lda sh_x
        clc
        adc #2
        jsr shot_pixels
+       inc sh_line
        dec sh_h
        bne -
_done   ldx iy
_next   dex
        bpl _shot
        rts

; A = pixel x (even), sh_line: two pixels of the shot
shot_pixels
        cmp #160
        bcs _out
        ldx sv_n
        cpx #MAX_SAVE
        bcs _out
        sta t0
        lsr a
        lsr a
        sta t1                          ; t1 = the column
        lda sh_line
        lsr a
        lsr a
        lsr a
        clc
        adc #PF_ROW
        tay                             ; Y = the row
        ldx t1
        jsr cell_addr
        ldy #0                          ; the brightest of the cell's colours
        lda (scrp),y
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda luma_tab,x
        sta t2
        lda #1
        sta t3                          ; t3 = its code
        lda (scrp),y
        and #$0f
        tax
        lda luma_tab,x
        cmp t2
        bcc +
        sta t2
        lda #2
        sta t3
+       lda (colp),y
        and #$0f
        tax
        lda luma_tab,x
        cmp t2
        bcc +
        sta t2
        lda #3
        sta t3
+       lda luma_tab+BG_COLOUR
        cmp t2
        bcc +
        lda #0
        sta t3
+       ldx t3
        lda code_pat,x
        sta t3
        lda sh_line                     ; the byte: its line in the cell
        and #7
        clc
        adc bmp
        sta bmp
        bcc +
        inc bmp+1
+       ldx sv_n
        lda bmp
        sta sv_lo,x
        lda bmp+1
        sta sv_hi,x
        ldy #0
        lda (bmp),y
        sta sv_val,x
        inc sv_n
        ldx #$f0                        ; pixels 0-1 or 2-3 of the byte
        lda t0
        and #2
        beq +
        ldx #$0f
+       stx t4
        lda t3
        and t4
        sta t3
        txa
        eor #$ff
        and (bmp),y
        ora t3
        sta (bmp),y
_out    rts

sh_w            .byte 0
sh_h            .byte 0
sh_x            .byte 0
sh_line         .byte 0
code_pat        .byte $00, $55, $aa, $ff
