; =============================================================================
; shots.asm - what is drawn straight into the bitmap, over the playfield, and
; taken away again before the next pass moves it:
;
; - the defenders' shots (too many for the sprites): a small block in the
;   brightest colour of the cell it is in;
; - the sprite objects the multiplexer had no sprite for (more than eight on
;   the same lines: a queue of invaders on a road across): their shape in two
;   tones, the cell's darkest colour and its brightest. They stay on the
;   screen instead of flickering.
;
; Every byte changed is kept and put back by shots_erase: a shot's bytes one
; by one (save_buf: address, old value), an object's a line at a time (ds_*:
; the address of the line's first byte, the three bytes 0, 8, 16 on). Anything else that draws on the playfield does so between
; shots_erase and the drawing (redraw_tile and the banner call shots_erase
; first). cell_codes (compose.asm) holds every playfield cell's darkest and
; brightest colour codes.
; =============================================================================

SAVE_LAST       = save_buf + (MAX_SAVE - 1) * 3

; the bitmap as it was
shots_erase
-       lda svp
        cmp #<save_buf
        bne +
        lda svp+1
        cmp #>save_buf
        beq _lines
+       lda svp                         ; back one record
        sec
        sbc #3
        sta svp
        bcs +
        dec svp+1
+       ldy #0
        lda (svp),y
        sta ptr
        iny
        lda (svp),y
        sta ptr+1
        iny
        lda (svp),y
        ldy #0
        sta (ptr),y
        jmp -
_lines  ldx ds_n                        ; then the objects' lines, last first
        beq save_reset
-       dex
        lda ds_lo,x
        sta ptr
        lda ds_hi,x
        sta ptr+1
        ldy #16
        lda ds_b2,x
        sta (ptr),y
        ldy #8
        lda ds_b1,x
        sta (ptr),y
        ldy #0
        lda ds_b0,x
        sta (ptr),y
        txa
        bne -

; nothing kept
save_reset
        lda #0
        sta ds_n
        lda #<save_buf
        sta svp
        lda #>save_buf
        sta svp+1
        rts

; bmp = a bitmap byte, t3 = the bits to set, t4 = their mask: the byte kept,
; then changed (nothing when the buffer is full).  Uses A, Y.
save_put
        lda svp+1
        cmp #>SAVE_LAST
        bcc +
        bne _full
        lda svp
        cmp #<SAVE_LAST
        bcc +
        beq +
_full   rts
+       ldy #0
        lda bmp
        sta (svp),y
        iny
        lda bmp+1
        sta (svp),y
        ldy #0
        lda (bmp),y
        ldy #2
        sta (svp),y
        lda svp
        clc
        adc #3
        sta svp
        bcc +
        inc svp+1
+       ldy #0
        lda t4
        eor #$ff
        and (bmp),y
        ora t3
        sta (bmp),y
        rts

; X = playfield row -> ptr2 = its row of cell_codes.  Preserves X, Y.
codes_row
        lda cc_row_lo,x
        sta ptr2
        lda cc_row_hi,x
        sta ptr2+1
        rts

; =============================================================================
; the shots
; =============================================================================
shots_draw
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

; A = pixel x (even), sh_line: two pixels of a shot
shot_pixels
        cmp #160
        bcs _out
        sta t0
        lsr a
        lsr a
        sta t1                          ; t1 = the column
        lda sh_line
        lsr a
        lsr a
        lsr a
        tax                             ; X = the playfield row
        jsr codes_row
        ldy t1
        lda (ptr2),y                    ; the cell's brightest colour
        and #3
        tay
        lda code_pat,y
        sta t3
        txa
        clc
        adc #PF_ROW
        tay
        ldx t1
        jsr cell_addr
        lda sh_line                     ; its line in the cell
        and #7
        clc
        adc bmp
        sta bmp
        bcc +
        inc bmp+1
+       lda t0                          ; pixels 0-1 or 2-3 of the byte
        and #2
        beq +
        lda #$0f
        bne ++
+       lda #$f0
+       sta t4
        and t3
        sta t3
        jmp save_put
_out    rts

sh_w            .byte 0
sh_h            .byte 0
sh_x            .byte 0
sh_line         .byte 0
code_pat        .byte $00, $55, $aa, $ff

; =============================================================================
; the objects without a sprite
; =============================================================================
dropped_draw
        ldx #0
_obj    cpx ob_n
        bcc +
        rts
+       lda ob_drop,x
        beq _next
        stx dd_i
        jsr drop_one
        ldx dd_i
_next   inx
        jmp _obj

; X = object: its shape into the bitmap, line by line
drop_one
        lda ds_n                        ; room for its 12 lines?
        cmp #DS_MAX - 11
        bcc +
        rts
+       ldy ob_spr,x
        lda spr_src_lo,y                ; src = its sprite's picture
        sta src
        lda spr_src_hi,y
        sta src+1
        lda #0
        sta dd_fast
        sta dd_mrow
        cpy #SPR_FIRST_FX               ; an invader: its masks are ready
        bcs +
        inc dd_fast
        lda emask_lo,y
        sta dd_mp
        lda emask_hi,y
        sta dd_mp+1
+
        lda spr_dark,y                  ; its own colour: dark or bright
        sta dd_dark
        lda ob_px,x                     ; pixel x = 2 * x: the column, and whether
        lsr a                           ; it starts half way into a byte
        sta dd_col
        lda #0
        rol a
        sta dd_half
        clc                             ; how many bytes across: 2, or 3 half way
        adc #2
        sta dd_n
        ldy #0                          ; (not past column 39: dd_cut)
        lda #40
        sec
        sbc dd_col
        cmp dd_n
        bcs +
        sta dd_n
        iny
+       sty dd_cut
        lda ob_line,x
        sta dd_line
        lda #0
        sta dd_srow
        jsr _cells
_line   lda dd_line
        cmp #PF_ROWS*8
        bcc +
        rts
+       lda dd_fast                     ; the masks for this line: dark (dd_d),
        beq _slow                       ; bright (dd_b)
        ldy dd_mrow                     ; an invader's: made at the start
        lda (dd_mp),y
        sta dd_d
        iny
        lda (dd_mp),y
        sta dd_d+1
        iny
        lda (dd_mp),y
        sta dd_b
        iny
        lda (dd_mp),y
        sta dd_b+1
        lda #0
        sta dd_d+2
        sta dd_b+2
        beq _gotm                       ; (always)
_slow   ldy dd_srow                     ; the others': from the sprite's two bytes
        lda (src),y
        sta t0
        iny
        lda (src),y
        sta t1
        jsr dd_masks
_gotm   lda dd_mrow
        clc
        adc #4
        sta dd_mrow
        lda dd_d                        ; nothing on this line?
        ora dd_d+1
        ora dd_b
        ora dd_b+1
        bne +
        jmp _empty
+       lda dd_half
        beq +
        jsr dd_shift
+       lda dd_cut                      ; (at the right edge: nothing past column 39)
        beq +
        jsr dd_clip
+       ldx ds_n                        ; the line's record
        lda bmp
        sta ds_lo,x
        lda bmp+1
        sta ds_hi,x
        .for i = 0, i < 3, i += 1
        .if i == 2
        lda dd_half                     ; (not half way: the third byte only kept)
        bne +
        ldy #16
        lda (bmp),y
        sta ds_b2,x
        jmp _kept
+
        .endif
        lda dd_d+i                      ; t5 = the pixels' colours, t4 = the rest kept
        and dd_pd+i
        sta t5
        lda dd_b+i
        and dd_pb+i
        ora t5
        sta t5
        lda dd_d+i
        ora dd_b+i
        eor #$ff
        sta t4
        ldy #i * 8
        lda (bmp),y
        sta ds_b0+i*DS_MAX,x
        and t4
        ora t5
        sta (bmp),y
        .endfor
_kept   inc ds_n
_empty
        inc dd_line                     ; the next line
        lda dd_srow
        clc
        adc #3
        sta dd_srow
        cmp #12*3
        beq _done
        lda dd_line
        and #7
        beq +
        inc bmp                         ; (in the same cell row: one byte on)
        bne _line
        inc bmp+1
        bne _line                       ; (always)
+       jsr _cells                      ; a new cell row
        jmp _line
_done   rts

; dd_line: bmp = its first byte, dd_pd / dd_pb = the dark and bright
; patterns of the cells it crosses
_cells  lda dd_line
        cmp #PF_ROWS*8
        bcs _r
        lsr a
        lsr a
        lsr a
        tax
        jsr codes_row
        txa
        clc
        adc #PF_ROW
        tay
        ldx dd_col
        jsr cell_addr
        lda dd_line
        and #7
        clc
        adc bmp
        sta bmp
        bcc +
        inc bmp+1
+       ldx #0
-       txa
        clc
        adc dd_col
        tay
        lda (ptr2),y                    ; dark << 2 | bright
        pha
        and #3
        tay
        lda code_pat,y
        sta dd_pb,x
        pla
        lsr a
        lsr a
        tay
        lda code_pat,y
        sta dd_pd,x
        inx
        cpx dd_n
        bcc -
_r      rts

; t0, t1 = 8 pixels of a sprite line -> dd_d, dd_b: the pixels to show
; dark and bright (3 bytes each, the third empty).  mask_tabs (gfx.asm):
; 0, 1 dark, bright when the sprite's own colour is bright; 2, 3 when dark
dd_masks  lda dd_dark
        bne dd_dk
        ldy t0
        lda mask_tabs,y
        sta dd_d
        lda mask_tabs+256,y
        sta dd_b
        ldy t1
        lda mask_tabs,y
        sta dd_d+1
        lda mask_tabs+256,y
        sta dd_b+1
        jmp dd_z
dd_dk   ldy t0
        lda mask_tabs+512,y
        sta dd_d
        lda mask_tabs+768,y
        sta dd_b
        ldy t1
        lda mask_tabs+512,y
        sta dd_d+1
        lda mask_tabs+768,y
        sta dd_b+1
dd_z    lda #0
        sta dd_d+2
        sta dd_b+2
        rts

; the masks two pixels (4 bits) on: d0 d1 -> d0>>4, d0<<4 | d1>>4, d1<<4
dd_shift  ldx #0
        jsr dd_sh
        ldx #dd_b-dd_d
dd_sh   ldy dd_d+1,x
        lda SWAPTAB,y
        tay
        and #$f0
        sta dd_d+2,x
        tya
        and #$0f
        sta t0
        ldy dd_d,x
        lda SWAPTAB,y
        tay
        and #$0f
        sta dd_d,x
        tya
        and #$f0
        ora t0
        sta dd_d+1,x
        rts

; dd_cut: the masks of the bytes past column 39 empty (they are written
; back as they were)
dd_clip lda #0
        sta dd_d+2
        sta dd_b+2
        ldx dd_n
        cpx #2
        bcs +
        sta dd_d+1
        sta dd_b+1
+       rts

; at the start: SWAPTAB, and the invaders' masks for every line (EMASK:
; 12 lines of dark, dark, bright, bright per sprite)
masks_init
        ldx #0
-       txa
        asl a
        adc #$80
        rol a
        asl a
        adc #$80
        rol a
        asl a
        adc #$80
        rol a
        asl a
        adc #$80
        rol a
        sta SWAPTAB,x
        inx
        bne -
        lda #<EMASK
        sta dd_mp
        lda #>EMASK
        sta dd_mp+1
        ldx #0                          ; X = the sprite
_spr    lda spr_src_lo,x
        sta src
        lda spr_src_hi,x
        sta src+1
        lda spr_dark,x
        sta dd_dark
        stx dd_i
        ldy #0
        sty dd_srow
-       ldy dd_srow
        lda (src),y
        sta t0
        iny
        lda (src),y
        sta t1
        jsr dd_masks
        ldy #0
        lda dd_d
        sta (dd_mp),y
        iny
        lda dd_d+1
        sta (dd_mp),y
        iny
        lda dd_b
        sta (dd_mp),y
        iny
        lda dd_b+1
        sta (dd_mp),y
        lda dd_mp
        clc
        adc #4
        sta dd_mp
        bcc +
        inc dd_mp+1
+       lda dd_srow
        clc
        adc #3
        sta dd_srow
        cmp #12*3
        bne -
        ldx dd_i
        inx
        cpx #SPR_FIRST_FX
        bne _spr
        rts

SPR_FIRST_FX    = SPR_SPARK_A           ; the invaders' sprites come first
emask_lo        .byte <(EMASK + range(SPR_FIRST_FX) * 48)
emask_hi        .byte >(EMASK + range(SPR_FIRST_FX) * 48)
        .cerror EMASK + SPR_FIRST_FX * 48 > SWAPTAB, "the masks run into SWAPTAB"

ds_n            .byte 0                 ; the lines kept (ds_*, main.asm)
dd_i            .byte 0
dd_dark         .byte 0
dd_col          .byte 0
dd_half         .byte 0
dd_line         .byte 0
dd_srow         .byte 0
dd_n            .byte 0
dd_cut          .byte 0
dd_fast         .byte 0
dd_mrow         .byte 0

; the sprites' pictures (their copies in the program, as they went to SPRITES)
spr_src_lo      .byte <(sprite_data + range(NUM_SPRITES) * 64)
spr_src_hi      .byte >(sprite_data + range(NUM_SPRITES) * 64)
; the rows of cell_codes
cc_row_lo       .byte <(cell_codes + range(PF_ROWS) * 40)
cc_row_hi       .byte >(cell_codes + range(PF_ROWS) * 40)
