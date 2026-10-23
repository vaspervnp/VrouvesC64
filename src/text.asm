; =============================================================================
; text.asm - the CPC's 3x6 font in the bitmap, a letter a cell (or 2 x 2
; cells, twice the size), and the texts: byte-pair packed glyph codes
; (tools/mkdata64.py), $fe a new line, $ff the end.
; =============================================================================

; X = column, Y = row: where the next letter goes (and new lines start)
set_at
        stx txt_col
        stx txt_col0
        sty txt_row
        rts

; X = letters' colour, Y = background
set_colors
        stx txt_fg
        sty txt_bg
        rts

; A = glyph: drawn at txt_col, txt_row, which moves on
put_glyph
        sta t0
        asl a                           ; ptr2 = font + 6 * glyph (3 * glyph < 256)
        adc t0
        asl a
        sta ptr2
        lda #0
        rol a
        sta ptr2+1
        lda ptr2
        clc
        adc #<font
        sta ptr2
        lda ptr2+1
        adc #>font
        sta ptr2+1
        lda txt_fg                      ; the cell's colours
        asl a
        asl a
        asl a
        asl a
        ora txt_bg
        sta t1
        lda txt_big
        bne _big
        ldx txt_col
        ldy txt_row
        jsr cell_addr
        ldy #0
        lda t1
        sta (scrp),y
        lda #$aa                        ; a blank line, 6 of the letter, a blank
        sta (bmp),y
        ldy #7
        sta (bmp),y
        ldy #5
-       lda (ptr2),y
        tax
        lda glyph_pat,x
        iny
        sta (bmp),y
        dey
        dey
        bpl -
        inc txt_col
        rts
_big    ldx txt_col                     ; 2 x 2 cells: 2 blank lines, each of
        ldy txt_row                     ; the 6 rows twice, 2 blank
        jsr cell_addr
        ldy #0
        lda t1
        sta (scrp),y
        iny
        sta (scrp),y
        ldy #40
        sta (scrp),y
        iny
        sta (scrp),y
        lda bmp                         ; src = the cells below
        clc
        adc #<320
        sta src
        lda bmp+1
        adc #>320
        sta src+1
        .for L = 0, L < 16, L += 1
        .if L < 2 || L >= 14
        lda #$aa
        ldy #L % 8
        sta (L < 8 ? bmp : src),y
        ldy #L % 8 + 8
        sta (L < 8 ? bmp : src),y
        .else
        ldy #(L - 2) / 2
        lda (ptr2),y
        tax
        lda big_l,x
        ldy #L % 8
        sta (L < 8 ? bmp : src),y
        lda big_r,x
        ldy #L % 8 + 8
        sta (L < 8 ? bmp : src),y
        .endif
        .endfor
        inc txt_col
        inc txt_col
        rts

; glyph_pat, big_l, big_r: data/gfx.asm

; normal size, twice the size
text_normal
        lda #0
        sta txt_big
        rts
text_big
        lda #1
        sta txt_big
        rts

; A = text id -> ptr = the text in the active language
get_str
        cmp #FIRST_STAGE_STR
        bcs _stage
        tax
        lda lang
        bne +
        lda strtab_en_lo,x
        sta ptr
        lda strtab_en_hi,x
        sta ptr+1
        rts
+       lda strtab_gr_lo,x
        sta ptr
        lda strtab_gr_hi,x
        sta ptr+1
        rts
_stage  sec                             ; the stage's own: [stage*6 + text*2 + lang]
        sbc #FIRST_STAGE_STR
        asl a
        ora lang
        sta t0
        lda stage
        asl a
        adc stage
        asl a
        adc t0
        tax
        lda st_str_lo,x
        sta ptr
        lda st_str_hi,x
        sta ptr+1
        rts

; A = text id: printed at txt_col, txt_row
print_id
        jsr get_str
        ; (on to print_str)

; ptr = text: printed; ptr is left past its end
print_str
        ldy #0
        lda (ptr),y
        inc ptr
        bne +
        inc ptr+1
+       cmp #$ff
        beq _end
        jsr print_code
        jmp print_str
_end    rts

; A = a code: a glyph, a new line or a pair (two codes, each maybe a pair)
print_code
        cmp #$fe
        beq _nl
        cmp #NUM_GLYPHS
        bcc _glyph
        sbc #NUM_GLYPHS
        tax
        lda pair_b,x
        pha
        lda pair_a,x
        jsr print_code
        pla
        jmp print_code
_nl     lda txt_col0
        sta txt_col
        inc txt_row
        rts
_glyph  jmp put_glyph

; A = text id, Y = row: centred (its longest line)
print_id_centered
        sty txt_row
        pha
        jsr get_str
        jsr str_len
        lda #40
        sec
        sbc t5
        lsr a
        sta txt_col
        sta txt_col0
        pla
        jmp print_id

; ptr = text -> t5 = the length of its first line (in letters)
str_len
        lda ptr
        sta src
        lda ptr+1
        sta src+1
        lda #0
        sta t5
-       ldy #0
        lda (src),y
        inc src
        bne +
        inc src+1
+       cmp #$fe
        bcs +
        jsr len_code
        jmp -
+       rts

len_code
        cmp #NUM_GLYPHS
        bcc _one
        sbc #NUM_GLYPHS
        tax
        lda pair_b,x
        pha
        lda pair_a,x
        jsr len_code
        pla
        jmp len_code
_one    inc t5
        rts

; num = value, A = digits: printed, with spaces in front (pn_zero: zeros)
print_num
        sta t4
        ldx #4                          ; the five digits, most significant first
-       lda #0
        sta digits,x
        dex
        bpl -
        ldx #4
_div    lda #0                          ; num / 10, the remainder a digit
        sta t3
        ldy #16
-       asl num
        rol num+1
        rol t3
        lda t3
        sec
        sbc #10
        bcc +
        sta t3
        inc num
+       dey
        bne -
        lda t3
        sta digits,x
        dex
        bpl _div
        lda #5
        sec
        sbc t4
        tax                             ; X = the first digit shown
        lda #0
        sta t2                          ; t2 = a digit other than 0 seen
-       lda digits,x
        bne _d
        ldy t2
        bne _d
        cpx #4                          ; the last digit always shows
        beq _d
        lda pn_zero
        bne _d0
        lda #G_SPACE
        jmp _p
_d0     lda #0
_d      sta t2
        inc t2
        clc
        adc #G_0
_p      stx t6
        jsr put_glyph
        ldx t6
        inx
        cpx #5
        bne -
        rts

digits          .fill 5
