; =============================================================================
; compose.asm - a playfield cell (4 x 8 pixels) drawn from what is on it:
; the tile under it (CPC pens, two a byte: 8 x 12 tiles, so a cell row takes
; one or two tile rows), the defender standing there and the flag. The 32
; pixels' colours are counted; the background ($d021) and the three most
; common others become the cell's colours, and every other colour shows as
; the nearest of those four (dist_tab). tools/c64gfx.py does the same, for
; the previews.
; =============================================================================

; X = column (0-39), Y = row (0-20) of the playfield
compose_cell
        lda ban_on                      ; the banner keeps its rows
        beq +
        tya
        sec
        sbc #BAN_ROW
        cmp #3
        bcs +
        rts
+       jsr strip_clear                 ; (nothing drawn over its row)
        stx cv_x
        sty cv_y
        txa
        lsr a
        sta cv_tcol
        lda #0
        rol a
        asl a
        sta cv_half
        tya
        asl a
        asl a
        asl a
        sta cv_line
        lda #0
        sta cv_pix
_line   ldx cv_line
        lda mod12x4,x
        ora cv_half
        sta t1                          ; t1 = the bytes' offset in the tile
        ldy div12,x
        lda row_tm_lo,y
        sta ptr
        lda row_tm_hi,y
        sta ptr+1
        ldy cv_tcol
        lda (ptr),y                     ; the tile
        tax
        lda tad_lo,x
        sta tptr
        lda tad_hi,x
        sta tptr+1
        lda ptr                         ; the cell's type: ptr + NCELLS
        clc
        adc #<NCELLS
        sta ptr2
        lda ptr+1
        adc #>NCELLS
        sta ptr2+1
        lda (ptr2),y
        sta t2                          ; t2 = cmap (bit 7: a defender)
        ldx cv_pix
        ldy t1
        lda (tptr),y
        sta t3
        iny
        lda (tptr),y
        tay
        lda hi_colour,y
        sta pix+2,x
        lda lo_colour,y
        sta pix+3,x
        ldy t3
        lda hi_colour,y
        sta pix,x
        lda lo_colour,y
        sta pix+1,x
        lda t2
        bpl _noov
        and #$1f                        ; the defender: its picture
        tay
        lda t_type,y
        tax
        lda t_dis,y
        beq +
        ldx #7                          ; a dented cauldron
+       lda ov_lo-1,x
        sta optr
        lda ov_hi-1,x
        sta optr+1
        ldx cv_pix
        ldy t1
        jsr overlay2
_noov   jsr flag_line
        lda cv_pix
        clc
        adc #4
        sta cv_pix
        inc cv_line
        lda cv_line
        and #7
        beq +
        jmp _line
+       jsr quantize
        jsr cell_code
        ldx cv_x
        ldy cv_y
        iny
        iny
        jsr cell_addr
        ; (on to cell_write)

; the 32 codes in pix -> the cell at bmp, scrp, colp
cell_write
        ldy #0
        ldx #0
-       lda pix,x
        asl a
        asl a
        ora pix+1,x
        asl a
        asl a
        ora pix+2,x
        asl a
        asl a
        ora pix+3,x
        sta (bmp),y
        inx
        inx
        inx
        inx
        iny
        cpy #8
        bne -
        ldy #0
        lda cv_slot+1
        asl a
        asl a
        asl a
        asl a
        ora cv_slot+2
        sta (scrp),y
        lda cv_slot+3
        sta (colp),y
        rts

; the cell's darkest and brightest colours (their codes) -> cell_codes, for
; what shots.asm draws over it: dark << 2 | bright
cell_code
        ldx cv_y
        jsr codes_row
        lda #$ff
        sta t1                          ; the darkest so far
        lda #0
        sta t2                          ; the brightest so far
        ldx #3
-       ldy cv_slot,x
        lda luma_tab,y
        cmp t1
        bcs +
        sta t1
        stx t3
+       cmp t2
        bcc +
        sta t2
        stx t4
+       dex
        bpl -
        lda t3
        asl a
        asl a
        ora t4
        ldy cv_x
        sta (ptr2),y
        rts

; optr = an overlay (pens two a byte, 0 clear), Y = offset of the two bytes
; on this line, X = pix: its pixels over those in pix
overlay2
        lda (optr),y
        sta t3
        iny
        lda (optr),y
        tay
        lda hi_colour_t,y
        bmi +
        sta pix+2,x
+       lda lo_colour_t,y
        bmi +
        sta pix+3,x
+       ldy t3
        lda hi_colour_t,y
        bmi +
        sta pix,x
+       lda lo_colour_t,y
        bmi +
        sta pix+1,x
+       rts

; the flag over this line of the cell, if it is there
flag_line
        lda cv_line
        sec
        sbc flag_y
        cmp #8
        bcs _out
        asl a
        asl a
        sta t1                          ; t1 = its row's first byte
        lda cv_x                        ; the cell's bytes: 2x, 2x+1
        asl a
        sec
        sbc flag_x                      ; j = the flag's byte under the first
        sta t2
        ldx cv_pix
        jsr _byte
        inx
        inx
        inc t2
_byte   lda t2
        cmp #4
        bcs _out
        clc
        adc t1
        tay
        lda flag_frame
        beq +
        tya
        adc #32
        tay
+       lda ov_flag_a,y
        tay
        lda hi_colour_t,y
        bmi +
        sta pix,x
+       lda lo_colour_t,y
        bmi _out
        sta pix+1,x
_out    rts

; the colours of pix -> the cell's four (cv_slot) and pix as the codes
quantize
        ldx #15
        lda #0
-       sta cnt,x
        dex
        bpl -
        .for i = 0, i < 32, i += 1
        ldx pix+i
        inc cnt,x
        .endfor
        lda #$ff
        ldx #15
-       sta mapc,x
        dex
        bpl -
        lda #0
        sta cnt+BG_COLOUR
        sta mapc+BG_COLOUR
        lda #BG_COLOUR
        sta cv_slot
        ldy #1                          ; the three most common (ties: the lower)
_pick   ldx #0
        stx t1                          ; t1 = how many
        stx t2                          ; t2 = which
-       lda cnt,x
        cmp t1
        beq +
        bcc +
        sta t1
        stx t2
+       inx
        cpx #16
        bne -
        lda t1
        bne +
        lda #0                          ; none left: black (nothing shows it)
        sta cv_slot,y
        beq _next                       ; (always)
+       ldx t2
        txa
        sta cv_slot,y
        tya
        sta mapc,x
        lda #0
        sta cnt,x
_next   iny
        cpy #4
        bne _pick
        ldx #31                         ; every pixel's code
_code   ldy pix,x
        lda mapc,y
        bpl +
        jsr nearest
+       sta pix,x
        dex
        bpl _code
        rts

; Y = a colour that is none of the four -> A = the nearest one's code,
; kept in mapc.  Preserves X.
nearest
        stx t3
        tya
        asl a
        asl a
        asl a
        asl a
        sta t4                          ; colour * 16
        lda #$ff
        sta t1                          ; the best distance so far
        ldx #0
-       lda cv_slot,x
        ora t4
        sty t5
        tay
        lda dist_tab,y
        ldy t5
        cmp t1
        bcs +
        sta t1
        stx t2
+       inx
        cpx #4
        bne -
        lda t2
        sta mapc,y
        ldx t3
        rts

; the whole playfield
compose_all
        ldy #0
_r      ldx #0
-       stx t6
        sty t7
        jsr compose_cell
        ldx t6
        ldy t7
        inx
        cpx #40
        bne -
        iny
        cpy #PF_ROWS
        bne _r
        rts

; X = column, Y = row of a tile: its cells (2 x 2 or 2 x 3) drawn again
compose_tile
        stx t6
        sty t7
        tya                             ; the cell rows: 12 r / 8 .. (12 r + 11) / 8
        asl a
        adc t7
        asl a
        asl a                           ; 12 r
        sta cv_line0
        lsr a
        lsr a
        lsr a
        sta cv_r0
        lda cv_line0
        clc
        adc #11
        lsr a
        lsr a
        lsr a
        sta cv_r1
        lda t6
        asl a
        sta cv_c0
-       ldx cv_c0
        ldy cv_r0
        jsr compose_cell
        ldx cv_c0
        inx
        ldy cv_r0
        jsr compose_cell
        inc cv_r0
        lda cv_r1
        cmp cv_r0
        bcs -
        rts

; the flag's cells in both its frames, kept for bitmap_draw (fc_*), and
; the one of flag_frame on the screen
flag_cache
        lda flag_frame
        pha
        lda #1
        sta flag_frame
        jsr compose_flag
        ldx #FC_MAX * 10
        jsr _keep
        lda #0
        sta flag_frame
        jsr compose_flag
        ldx #0
        jsr _keep
        pla
        sta flag_frame
        sta flag_shown
        beq +
        jsr compose_flag
+       rts
_keep   ldy #0                          ; X = where in fc_data
-       sty t6
        stx t7
        ldx fc_col,y
        lda fc_row,y
        clc
        adc #PF_ROW
        tay
        jsr cell_addr
        ldx t7
        ldy #0
-       lda (bmp),y
        sta fc_data,x
        inx
        iny
        cpy #8
        bne -
        ldy #0
        lda (scrp),y
        sta fc_data,x
        lda (colp),y
        and #$0f
        sta fc_data+1,x
        inx
        inx
        ldy t6
        iny
        cpy fc_n
        bne --
        rts

; the cells under the flag drawn again (fc_*: which they are)
compose_flag
        lda #0
        sta fc_n
        lda flag_y                      ; the cell rows
        lsr a
        lsr a
        lsr a
        sta cv_r0
        sta fc_r0
        lda flag_y
        clc
        adc #7
        lsr a
        lsr a
        lsr a
        sta cv_r1
        sta fc_r1
        lda flag_x                      ; the cell columns: x/2 .. (x+3)/2
        lsr a
        sta fc_c0
        lda flag_x
        clc
        adc #3
        lsr a
        sta fc_c1
_fr     lda fc_c0
        sta cv_c0
-       ldx cv_c0
        ldy cv_r0
        txa
        ldx fc_n
        sta fc_col,x
        tya
        sta fc_row,x
        inc fc_n
        tax
        ldx cv_c0
        jsr compose_cell
        inc cv_c0
        lda fc_c1
        cmp cv_c0
        bcs -
        inc cv_r0
        lda cv_r1
        cmp cv_r0
        bcs _fr
        rts

cv_x            .byte 0
cv_y            .byte 0
cv_line         .byte 0
cv_tcol         .byte 0
cv_half         .byte 0
cv_pix          .byte 0
cv_slot         .fill 4
cv_line0        .byte 0
cv_r0           .byte 0
cv_r1           .byte 0
cv_c0           .byte 0
cv_c1           .byte 0
flag_x          .byte 0                 ; the stage's flag: two pixel units, lines
flag_y          .byte 0

; div12, mod12x4: data/gfx.asm
row_tm_lo       .byte <(tmap + range(NROW) * NCOL)
row_tm_hi       .byte >(tmap + range(NROW) * NCOL)
; the defenders' pictures by type (7: a dented cauldron)
ov_lo           .byte <ov_cretan, <ov_yiayia, <ov_bride, <ov_psssst, <ov_cauldron, <ov_baker, <ov_cauldron_x
ov_hi           .byte >ov_cretan, >ov_yiayia, >ov_bride, >ov_psssst, >ov_cauldron, >ov_baker, >ov_cauldron_x
