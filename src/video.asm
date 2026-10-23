; =============================================================================
; video.asm - the VIC: a multicolour bitmap over the whole screen, 40 x 25
; cells of 4 x 8 pixels. A cell shows $d021 (pixels %00, the grass green),
; its screen RAM's two colours (%01 the high nibble, %10 the low one) and its
; colour RAM (%11). Text cells use %01 for the letters and %10 behind them,
; so they never show $d021.
; =============================================================================

video_init
        lda CIA2_PRA                    ; VIC bank 3 ($c000-$ffff)
        and #$fc
        sta CIA2_PRA
        lda #VIC_MEM_GAME
        sta VIC_MEM
        lda #$18                        ; multicolour, 40 columns
        sta VIC_CTRL2
        lda #0
        sta VIC_BORDER
        lda #BG_COLOUR
        sta VIC_BG0
        lda #$ff
        sta VIC_SPR_MC
        lda #0
        sta VIC_SPR_YEXP
        sta VIC_SPR_XEXP
        sta VIC_SPR_PRIO
        lda #SPR_MC0
        sta VIC_SPR_MC0
        lda #SPR_MC1
        sta VIC_SPR_MC1
        jsr clear_screen
        ; (on to screen_on)

; the bitmap on show
screen_on
        lda #$3b
        sta VIC_CTRL1
        rts

; blank (the border colour everywhere): faster to draw, nothing seen
screen_off
        lda #$2b
        sta VIC_CTRL1
        rts

; the whole screen black (text background, no sprites)
clear_screen
        lda #0
        sta ob_n
        lda #0
        ldx #0
        ldy #25
        ; (on to fill_rows)

; A = colour, X = the first row, Y = rows: those rows cleared to the colour
fill_rows
        sta t2
        stx t0
        sty t1
        lda #0
        sta t3                          ; the column
        lda #40
        sta t4
        ; (on to fill_cells)

; t0 = row, t1 = rows, t3 = column, t4 = columns, t2 = colour: the cells
; cleared to the colour (as a text background, %10)
fill_cells
_row    ldx t0
        jsr cell_addr_x0
        ldy t3                          ; screen and colour RAM
        ldx t4
-       lda t2
        sta (scrp),y
        sta (colp),y
        iny
        dex
        bne -
        lda t3                          ; the bitmap: 8 bytes a cell
        asl a
        asl a
        asl a
        tay
        bcc +
        inc bmp+1
+       ldx t4
        lda #$aa
-       .for i = 0, i < 8, i += 1
        sta (bmp),y
        iny
        .endfor
        bne +
        inc bmp+1
+       dex
        bne -
        inc t0
        dec t1
        bne _row
        rts

; X = row -> bmp, scrp, colp at its column 0.  Preserves X, Y.
cell_addr_x0
        lda row_bmp_lo,x
        sta bmp
        lda row_bmp_hi,x
        sta bmp+1
        lda row_scr_lo,x
        sta scrp
        sta colp
        lda row_scr_hi,x
        sta scrp+1
        clc
        adc #(>$d800)-(>SCREEN)
        sta colp+1
        rts

; X = column, Y = row -> bmp, scrp, colp of that cell.  Preserves X, Y.
cell_addr
        txa
        clc
        adc row_scr_lo,y
        sta scrp
        sta colp
        lda row_scr_hi,y
        adc #0
        sta scrp+1
        adc #(>$d800)-(>SCREEN)
        sta colp+1
        txa
        asl a
        asl a
        asl a
        sta bmp
        txa
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        sta bmp+1
        lda bmp
        clc
        adc row_bmp_lo,y
        sta bmp
        lda bmp+1
        adc row_bmp_hi,y
        sta bmp+1
        rts

; a horizontal line across the screen: X = row, Y = line in it (0-7),
; A = colour (colour RAM, %11) - over cells whose background is black
hline
        sta t2
        sty t3
        jsr cell_addr_x0
        ldy #39
-       lda t2
        sta (colp),y
        dey
        bpl -
        lda bmp
        clc
        adc t3
        sta bmp
        bcc +
        inc bmp+1
+       ldx #40
        ldy #0
-       lda #$ff
        sta (bmp),y
        tya
        clc
        adc #8
        tay
        bne +
        inc bmp+1
+       dex
        bne -
        rts

; the cells' addresses by row
row_bmp_lo      .byte <(BITMAP + range(25) * 320)
row_bmp_hi      .byte >(BITMAP + range(25) * 320)
row_scr_lo      .byte <(SCREEN + range(25) * 40)
row_scr_hi      .byte >(SCREEN + range(25) * 40)

; wait for the next frame
wait_frame
        lda frame
-       cmp frame
        beq -
        rts

; A = frames to wait
wait_frames
        tax
-       jsr wait_frame
        dex
        bne -
        rts
