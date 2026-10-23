; =============================================================================
; mux.asm - the sprite multiplexer's list: up to MAX_OBJ objects a frame on
; the eight hardware sprites.
;
; ob_pin (the cursor) has sprite 0 to itself, in front of every other
; sprite, and never goes into the bitmap; the others share sprites 1-7.
;
; The objects (ob_y = the Y register, ob_x/ob_xh, ob_ptr, ob_col) are sorted
; by Y. Each one, in that order, goes to the sprite that has been free the
; longest: the first eight are set up by the frame's interrupt, every other
; one by an entry at the line where its sprite's last object has ended (a
; sprite shows 21 lines whatever it holds). Taking the sprite free the
; longest keeps these lines in order. An object with no sprite free in time
; gets ob_drop: shots.asm draws it into the bitmap instead, so nothing
; flickers. The objects come in the same order every frame, so in a crowd
; the same ones keep their sprites.
; =============================================================================

SPR_LINES       = 21
REUSE_GAP       = 3                     ; lines to move a sprite on

; the object list starts empty
obj_clear
        lda #0
        sta ob_n
        lda #$ff
        sta ob_pin
        rts

; A = Y register, X = x (two pixel units, 0-79), Y = sprite block,
; t0 = colour: one more object (if there is room).  Uses A, X.
obj_add
        stx t1
        ldx ob_n
        cpx #MAX_OBJ
        bcs _full
        sta ob_y,x
        tya
        clc
        adc #SPR_PTR0
        sta ob_ptr,x
        lda t0
        sta ob_col,x
        tya
        sta ob_spr,x
        lda ob_y,x
        sec
        sbc #SPR_Y0
        sta ob_line,x
        lda t1
        sta ob_px,x
        lda #0
        sta ob_drop,x
        lda t1                          ; X register = 24 + 4 * x
        asl a
        asl a
        php
        clc
        adc #SPR_X0
        sta ob_x,x
        lda #0
        rol a                           ; the carry of the add
        plp
        adc #0                          ; and of the shifts
        sta ob_xh,x
        inc ob_n
_full   rts

; the list for the IRQ from the objects; nothing if the last one has not
; been taken yet
mux_build
        lda dl_ready
        beq +
        rts
+       ldx ob_n                        ; sort by Y: insertion, starting from the
        beq _sorted                     ; order of the last list (nearly sorted)
        cpx mx_prev_n
        beq _keep
        stx mx_prev_n                   ; (another number of objects: from scratch)
        dex
-       txa
        sta ob_ord,x
        dex
        bpl -
_keep   ldx #1
_ins    cpx ob_n
        bcs _sorted
        stx t2                          ; t2 = the slot being placed
        lda ob_ord,x
        sta t1                          ; t1 = its object
        tay
        lda ob_y,y
        sta t3
        ldy t2                          ; Y = the slot it goes to
-       cpy #0
        beq _put
        ldx ob_ord-1,y
        lda ob_y,x
        cmp t3
        bcc _put                        ; (equal: stays after, the order kept)
        beq _put
        txa
        sta ob_ord,y
        dey
        jmp -
_put    lda t1
        sta ob_ord,y
        ldx t2
        inx
        jmp _ins
_sorted
        lda dl_show                     ; build the list not on show
        eor #MAX_OBJ
        sta t4                          ; t4 = its first entry
        sta t5                          ; t5 = the next entry
        beq +
        lda #8
+       sta t6                          ; t6 = its first-use base (0 or 8)
        lda #0
        sta t7                          ; t7 = sprites in use
        ldx #7
-       sta mx_free,x
        dex
        bpl -
        tax
        ldy t6
        lda #0
-       sta fs_msb_tmp
        sta fs_y,y                      ; unused sprites: off the screen
        iny
        inx
        cpx #8
        bne -
        ldx ob_pin                      ; the pinned one: sprite 0, all the frame
        bmi _nopin
        ldy t6
        lda ob_y,x
        sta fs_y,y
        lda ob_x,x
        sta fs_x,y
        lda ob_ptr,x
        sta fs_ptr,y
        lda ob_col,x
        sta fs_col,y
        lda ob_xh,x
        beq +
        lda #$01
        sta fs_msb_tmp
+       lda #$01
        sta t7
        lda #$ff
        sta mx_free
_nopin  lda #0
        sta t3                          ; t3 = the objects done
_obj    lda t3
        cmp ob_n
        bcc +
        jmp _done
+       tay
        ldx ob_ord,y                    ; X = the object
        cpx ob_pin
        bne +
        jmp _skip
+       ldy #0                          ; Y = the sprite free the longest
        lda mx_free
        sta t2
        .for spr = 1, spr < 8, spr += 1
        lda mx_free+spr
        cmp t2
        bcs +
        sta t2
        ldy #spr
+
        .endfor
        lda t7                          ; the sprite not used yet?
        and bit_tab,y
        bne _reuse
        lda t7
        ora bit_tab,y
        sta t7
        sty t1
        tya
        clc
        adc t6
        tay                             ; Y = its first-use slot
        lda ob_y,x
        sta fs_y,y
        lda ob_x,x
        sta fs_x,y
        lda ob_ptr,x
        sta fs_ptr,y
        lda ob_col,x
        sta fs_col,y
        lda ob_xh,x
        beq +
        ldy t1
        lda fs_msb_tmp
        ora bit_tab,y
        sta fs_msb_tmp
+       ldy t1
        jmp _taken
_reuse  lda ob_y,x                      ; free in time?
        sec
        sbc #REUSE_GAP
        bcc _drop
        cmp t2
        bcc _drop
        sty t1
        ldy t5                          ; an entry
        lda t2
        sta dl_line,y
        lda t1
        asl a
        sta dl_spr,y
        lda ob_y,x
        sta dl_y,y
        lda ob_x,x
        sta dl_x,y
        lda ob_ptr,x
        sta dl_ptr,y
        lda ob_col,x
        sta dl_col,y
        lda #0
        ldy ob_xh,x
        beq +
        ldy t1
        lda bit_tab,y
+       ldy t5
        sta dl_msb,y
        inc t5
        ldy t1
_taken  lda ob_y,x                      ; the sprite is busy until Y + 21 + 1
        clc
        adc #SPR_LINES+1
        bcc +
        lda #$ff
+       sta mx_free,y
        jmp _skip
_drop   lda #1                          ; no sprite: shots.asm draws it
        sta ob_drop,x
_skip   inc t3
        jmp _obj
_done   ldx #0                          ; the list's totals
        lda t4
        beq +
        inx
+       lda t5
        sec
        sbc t4
        sta dl_n,x
        lda t7
        sta fs_en,x
        lda fs_msb_tmp
        sta fs_msb,x
        lda #1
        sta dl_ready
        rts

fs_msb_tmp      .byte 0
mx_prev_n       .byte 0                 ; the objects in the last list
bit_tab         .byte 1,2,4,8,16,32,64,128
