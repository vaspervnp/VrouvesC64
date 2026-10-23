; =============================================================================
; shots.asm - what is drawn straight into the bitmap, over the playfield:
;
; - the defenders' shots (too many for the sprites): a small block in the
;   brightest colour of the cell it is in;
; - the sprite objects the multiplexer had no sprite for (more than seven on
;   the same lines: a queue of invaders on a road across): their shape in two
;   tones, the cell's darkest colour and its brightest;
; - the flag's other frame (compose.asm made both at the start).
;
; bitmap_draw does the playfield a cell row (a strip) at a time, each while
; the raster is away from it: what was drawn on the strip the last time is
; put back, then it is drawn anew. A strip shows the old picture or the new
; one, never neither, so nothing flickers.
;
; The bytes kept: a ring of line records (rg_*, main.asm: the address of the
; first byte and how many, 1-3, at 0, 8, 16 on; their old values), a block
; of it per strip (st_start..st_end), the strips' blocks in order. Anything
; else that draws on the playfield puts its strip back first (strip_clear:
; compose_cell does it). cell_codes (compose.asm) holds every playfield
; cell's darkest and brightest colour codes.
; =============================================================================

STRIP_TOP       = 51 + PF_ROW * 8       ; the raster line of strip 0

; nothing kept (the playfield is drawn afresh)
save_reset
        lda #0
        sta rg_head
        ldx #PF_ROWS
-       sta st_start,x
        sta st_end,x
        dex
        bpl -
        rts

; the bitmap as it was, everywhere
shots_erase
        ldy #PF_ROWS-1
-       jsr strip_clear
        dey
        bpl -
        rts

; Y = playfield row: what was drawn over it put back, the last first.
; Preserves X, Y.
strip_clear
        lda st_end,y
        cmp st_start,y
        bne +
        rts
+       stx sc_x
        sty sc_y
        tax
-       dex
        lda rg_lo,x
        sta rp
        lda rg_hi,x
        ora #$e0
        sta rp+1
        lda rg_hi,x
        and #$60
        beq _1
        cmp #$20
        beq _2
        ldy #16
        lda rg_b2,x
        sta (rp),y
_2      ldy #8
        lda rg_b1,x
        sta (rp),y
_1      ldy #0
        lda rg_b0,x
        sta (rp),y
        ldy sc_y
        txa
        cmp st_start,y
        bne -
        sta st_end,y
        ldx sc_x
        rts

; X = playfield row -> ptr2 = its row of cell_codes.  Preserves X, Y.
codes_row
        lda cc_row_lo,x
        sta ptr2
        lda cc_row_hi,x
        sta ptr2+1
        rts

; X = strip, A = raster lines of work more (saturating).  Preserves A, X.
bd_add  cpx #PF_ROWS
        bcs _r
        sta t0
        clc
        adc st_work,x
        bcc +
        lda #$ff
+       sta st_work,x
        lda t0
_r      rts

; =============================================================================
; the pass's drawing: the objects without a sprite, the shots, the flag
; =============================================================================
bitmap_draw
        ldx #PF_ROWS-1                  ; the work on each strip, in raster lines
        lda #0
-       sta st_work,x
        dex
        bpl -
        sta bd_n
        lda flag_frame                  ; the flag's other frame
        cmp flag_shown
        beq _objs
        lda #12
        ldx fc_r0
        jsr bd_add
        ldx fc_r1
        jsr bd_add
_objs   ldy #0                          ; the objects without a sprite, top first
_ob     cpy ob_n
        bcs _shots
        ldx ob_ord,y
        lda ob_drop,x
        beq _nob
        lda ob_line,x
        cmp #PF_ROWS*8
        bcs _nob
        txa
        ldx bd_n
        sta bd_list,x
        inc bd_n
        tax
        lda ob_line,x                   ; 12 lines from o = line & 7: two strips
        and #7                          ; or three
        sta t1
        lda ob_line,x
        lsr a
        lsr a
        lsr a
        tax
        sty t2
        ldy t1
        lda bd_w0,y
        jsr bd_add
        inx
        lda bd_w1,y
        jsr bd_add
        inx
        lda bd_w2,y
        jsr bd_add
        ldy t2
_nob    iny
        bne _ob                         ; (always)
_shots  ldx #MAX_PR-1                   ; the shots: one strip, or two
-       lda p_type,x
        beq _nsh
        tay
        lda p_y,x
        cmp #PF_ROWS*8
        bcs _nsh
        stx t2
        clc
        adc shot_h-1,y
        sbc #0                          ; (the last line)
        lsr a
        lsr a
        lsr a
        sta t1
        lda p_y,x
        lsr a
        lsr a
        lsr a
        tax
        lda #8
        jsr bd_add
        cpx t1
        beq +
        ldx t1
        jsr bd_add
+       ldx t2
_nsh    dex
        bpl -

        ldy #0                          ; the strips, in turn
_s      lda st_end,y                    ; the work: the lines to put back, and to draw
        sec
        sbc st_start,y
        clc
        adc st_work,y
        bcc +
        lda #$ff
+       cmp #0
        bne _do
        lda rg_head                     ; nothing: an empty block
        sta st_start,y
        sta st_end,y
        jmp _next
_do     clc                             ; (and the interrupts)
        adc #8
        bcc +
        lda #$ff
+       sta t0
        lda st_top,y                    ; the raster not on the strip, nor coming
        sec                             ; to it before the work is done
        sbc t0
        bcs +
        lda #0
+       sta bd_lo
        lda st_top,y
        clc
        adc #9
        sta bd_hi
-       lda VIC_CTRL1
        bmi +
        lda VIC_RASTER
        cmp bd_lo
        bcc +
        cmp bd_hi
        bcc -
+       sty bd_s
        jsr strip_clear
        lda rg_head
        sta st_start,y
        lda flag_frame                  ; the flag
        cmp flag_shown
        beq +
        jsr flag_row
+       jsr bd_objs
        jsr bd_shots
        ldy bd_s
        lda rg_head
        sta st_end,y
_next   iny
        cpy #PF_ROWS
        beq +
        jmp _s
+       lda rg_head
        sta st_start+PF_ROWS
        lda flag_frame
        sta flag_shown
        rts

; the lines of a strip each object's 12 cover, in raster lines of work
bd_w0   .byte 5 * (8 - range(8)) + 3
bd_w1   .byte 5 * 4 + 3, 5 * 5 + 3, 5 * 6 + 3, 5 * 7 + 3, 5 * 8 + 3, 5 * 8 + 3, 5 * 8 + 3, 5 * 8 + 3
bd_w2   .byte 0, 0, 0, 0, 0, 5 + 3, 10 + 3, 15 + 3
; the strips' first raster lines
st_top  .byte STRIP_TOP + range(PF_ROWS) * 8

; bd_s: the flag's cells on this strip, its new frame (compose.asm made them)
flag_row
        ldx #0
-       cpx fc_n
        bcs _r
        lda fc_row,x
        cmp bd_s
        bne _nc
        stx t1
        tay
        lda fc_col,x
        tax
        tya
        clc
        adc #PF_ROW
        tay
        jsr cell_addr
        lda t1                          ; Y = its 10 bytes in fc_data
        asl a
        asl a
        adc t1
        asl a
        ldx flag_frame
        beq +
        adc #FC_MAX * 10
+       tax
        ldy #0
-       lda fc_data,x
        sta (bmp),y
        inx
        iny
        cpy #8
        bne -
        ldy #0
        lda fc_data,x
        sta (scrp),y
        lda fc_data+1,x
        sta (colp),y
        ldx t1
_nc     inx
        bne --                          ; (always)
_r      rts

; =============================================================================
; the objects without a sprite
; =============================================================================
bd_objs
        lda bd_s
        asl a
        asl a
        asl a
        sta dd_top                      ; the strip's first line
        ldx #0
-       cpx bd_n
        bcs +
        stx bd_i
        lda bd_list,x
        tax
        jsr drop_part
        ldx bd_i
        inx
        bne -                           ; (always)
+       rts

; X = object: its lines on strip bd_s into the bitmap
drop_part
        lda ob_line,x                   ; the lines: from dd_o in the strip, from
        sec                             ; dd_row of the sprite, dd_cnt of them
        sbc dd_top
        bcc _above
        cmp #8
        bcs _r
        sta dd_o
        lda #0
        sta dd_row
        lda #8
        sec
        sbc dd_o
        bne _cnt                        ; (always)
_above  eor #$ff
        adc #1                          ; (C clear) the rows above the strip
        cmp #12
        bcs _r
        sta dd_row
        lda #0
        sta dd_o
        lda #12
        sec
        sbc dd_row
        cmp #9
        bcc _cnt
        lda #8
_cnt    sta dd_cnt
        ldy bd_s                        ; room in the ring?
        lda rg_head
        sec
        sbc st_start+1,y
        clc
        adc dd_cnt
        bcs _r
        cmp #255
        bcc +
_r      rts
+       ldy ob_spr,x
        lda spr_src_lo,y                ; src = its sprite's picture
        sta src
        lda spr_src_hi,y
        sta src+1
        lda #0
        sta dd_fast
        cpy #SPR_FIRST_FX               ; an invader: its masks are ready
        bcs +
        inc dd_fast
        lda emask_lo,y
        sta dd_mp
        lda emask_hi,y
        sta dd_mp+1
+       lda spr_dark,y                  ; its own colour: dark or bright
        sta dd_dark
        lda dd_row
        asl a
        sta dd_srow
        adc dd_row
        sta dd_srow                     ; 3 bytes a sprite row
        lda dd_row
        asl a
        asl a
        sta dd_mrow                     ; 4 bytes a mask row
        lda ob_px,x                     ; pixel x = 2 * x: the column, and whether
        lsr a                           ; it starts half way into a byte
        sta dd_col
        lda #0
        rol a
        sta dd_half
        clc                             ; how many bytes across: 2, or 3 half way
        adc #2
        sta dd_n
        lda #40                         ; (not past column 39)
        sec
        sbc dd_col
        cmp dd_n
        bcs +
        sta dd_n
+       lda dd_n
        sec
        sbc #1
        asl a
        asl a
        asl a
        asl a
        asl a
        sta dd_nbits                    ; (the record's count)
        ldx bd_s                        ; the cells: their address, their colours
        jsr codes_row
        txa
        clc
        adc #PF_ROW
        tay
        ldx dd_col
        jsr cell_addr
        lda bmp
        ora dd_o
        sta bmp
        ldx #0
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

_line   lda dd_fast                     ; the masks for this line: dark (dd_d),
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
        lda dd_srow
        adc #3
        sta dd_srow
        lda dd_d                        ; nothing on this line?
        ora dd_d+1
        ora dd_b
        ora dd_b+1
        bne +
        jmp _empty
+       lda dd_half
        beq +
        jsr dd_shift
+       ldx rg_head                     ; the line's record
        lda bmp
        sta rg_lo,x
        lda bmp+1
        and #$1f
        ora dd_nbits
        sta rg_hi,x
        .for i = 0, i < 3, i += 1
        .if i > 0
        lda dd_n
        cmp #i+1
        bcc _kept
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
        sta rg_b0+i*256,x
        and t4
        ora t5
        sta (bmp),y
        .endfor
_kept   inc rg_head
_empty  inc bmp                         ; the next line (in the same cell)
        dec dd_cnt
        beq +
        jmp _line
+       rts

; =============================================================================
; the shots
; =============================================================================
bd_shots
        ldx #MAX_PR-1
_shot   lda p_type,x
        bne +
        jmp _next
+       stx iy
        tay
        lda shot_h-1,y
        sta sh_h
        lda shot_w-1,y
        sta sh_w
        lda p_y,x                       ; its lines on the strip: from dd_o, sh_n
        sec
        sbc dd_top
        bcc _above
        cmp #8
        bcs _no
        sta dd_o
        lda #8
        sec
        sbc dd_o
        cmp sh_h
        bcc _cnt
        lda sh_h
        bcs _cnt                        ; (always)
_above  eor #$ff
        adc #1                          ; (C clear) its lines above the strip
        cmp sh_h
        bcs _no
        eor #$ff
        sec
        adc sh_h                        ; h - those
        ldy #0
        sty dd_o
_cnt    sta sh_n
        lda p_x,x                       ; the pixels: x (even), 2 or 4 of them
        and #$fe
        cmp #160
        bcs _no
        sta t0
        lsr a
        lsr a
        sta sh_col
        lda #$f0                        ; the masks of one byte or two
        sta sh_m0
        lda #0
        sta sh_m1
        lda t0
        and #2
        beq +
        lda #$0f
        sta sh_m0
        lda sh_w
        cmp #4
        bcc ++
        lda #$f0
        sta sh_m1
        bne ++                          ; (always)
+       lda sh_w
        cmp #4
        bcc +
        lda #$ff
        sta sh_m0
+       lda sh_col                      ; (not past column 39)
        cmp #39
        bcc +
        lda #0
        sta sh_m1
+       ldy bd_s                        ; room in the ring?
        lda rg_head
        sec
        sbc st_start+1,y
        clc
        adc sh_n
        bcs _no
        cmp #255
        bcc +
_no     jmp _next
+       ldx bd_s                        ; the cells' brightest colours
        jsr codes_row
        ldy sh_col
        lda (ptr2),y
        and #3
        tay
        lda code_pat,y
        and sh_m0
        sta sh_p0
        ldy sh_col
        iny
        lda (ptr2),y
        and #3
        tay
        lda code_pat,y
        and sh_m1
        sta sh_p1
        lda bd_s
        clc
        adc #PF_ROW
        tay
        ldx sh_col
        jsr cell_addr
        lda bmp
        ora dd_o
        sta bmp
        lda sh_m0
        eor #$ff
        sta sh_m0
        lda sh_m1                       ; (the record: 1 byte, or 2)
        beq +
        eor #$ff
        sta sh_m1
        lda #$20
+       sta t3
-       ldx rg_head
        lda bmp
        sta rg_lo,x
        lda bmp+1
        and #$1f
        ora t3
        sta rg_hi,x
        ldy #0
        lda (bmp),y
        sta rg_b0,x
        and sh_m0
        ora sh_p0
        sta (bmp),y
        lda t3
        beq +
        ldy #8
        lda (bmp),y
        sta rg_b1,x
        and sh_m1
        ora sh_p1
        sta (bmp),y
+       inc rg_head
        inc bmp
        dec sh_n
        bne -
        ldx iy
_next   dex
        bmi +
        jmp _shot
+       rts

sh_w            .byte 0
sh_h            .byte 0
sh_n            .byte 0
sh_col          .byte 0
sh_m0           .byte 0
sh_m1           .byte 0
sh_p0           .byte 0
sh_p1           .byte 0
code_pat        .byte $00, $55, $aa, $ff
sc_x            .byte 0
sc_y            .byte 0
bd_n            .byte 0
bd_i            .byte 0
bd_s            .byte 0
bd_lo           .byte 0
bd_hi           .byte 0
dd_i            .byte 0
dd_top          .byte 0
dd_o            .byte 0
dd_row          .byte 0
dd_cnt          .byte 0
dd_nbits        .byte 0
flag_shown      .byte 0

; t0, t1 = 8 pixels of a sprite line -> dd_d, dd_b: the pixels to show
; dark and bright (3 bytes each, the third empty).  Uses X, t2-t4.
dd_masks
        lda t0
        jsr dd_pm
        lda t3
        sta dd_d
        lda t4
        sta dd_b
        lda t1
        jsr dd_pm
        lda t3
        sta dd_d+1
        lda t4
        sta dd_b+1
        lda #0
        sta dd_d+2
        sta dd_b+2
        rts

; A = 4 pixels -> t3, t4: those shown dark, bright. Multicolour 0 (black)
; dark, 1 (light grey) bright, the sprite's own colour as spr_dark says
dd_pm   sta t2
        lda #0
        sta t3
        sta t4
        ldx #4
_p      asl t3
        asl t3
        asl t4
        asl t4
        lda t2
        and #$c0
        beq _nx
        cmp #$40
        beq _dk
        cmp #$c0
        beq _br
        lda dd_dark
        bne _dk
_br     lda t4
        ora #3
        sta t4
        bne _nx                         ; (always)
_dk     lda t3
        ora #3
        sta t3
_nx     asl t2
        asl t2
        dex
        bne _p
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

dd_dark         .byte 0
dd_col          .byte 0
dd_half         .byte 0
dd_line         .byte 0
dd_srow         .byte 0
dd_n            .byte 0
dd_fast         .byte 0
dd_mrow         .byte 0

; the sprites' pictures (their copies in the program, as they went to SPRITES)
spr_src_lo      .byte <(sprite_data + range(NUM_SPRITES) * 64)
spr_src_hi      .byte >(sprite_data + range(NUM_SPRITES) * 64)
; the rows of cell_codes
cc_row_lo       .byte <(cell_codes + range(PF_ROWS) * 40)
cc_row_hi       .byte >(cell_codes + range(PF_ROWS) * 40)
