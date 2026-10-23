; =============================================================================
; irq.asm - the raster interrupts: the frame (in the bottom border) and the
; sprite multiplexer's (mux.asm builds the lists they read).
;
; The frame's interrupt takes a new list if one is ready, sets each hardware
; sprite to its first object of the frame, counts the frame and runs the
; music. Then one interrupt for each group of list entries, at the line
; where the sprite's last object has ended: the sprite moves on down to its
; next object.
; =============================================================================

irq_init
        lda #FRAME_LINE
        sta VIC_RASTER
        lda VIC_CTRL1
        and #$7f
        sta VIC_CTRL1
        lda #1
        sta VIC_IRQ_MASK
        sta VIC_IRQ
        rts

irq_frame
        pha
        txa
        pha
        tya
        pha
        cld
        lda #1
        sta VIC_IRQ
        lda dl_ready                    ; a new list: show it
        beq +
        lda dl_show
        eor #MAX_OBJ
        sta dl_show
        lda #0
        sta dl_ready
+       ldx dl_show                     ; X = 0 or MAX_OBJ
        beq +
        ldx #1
+       lda fs_en,x
        sta VIC_SPR_ENA
        lda fs_msb,x
        sta msb_shadow
        sta VIC_SPR_XMSB
        txa                             ; the first object of each sprite
        asl a
        asl a
        asl a
        tax
        ldy #0
-       lda fs_y,x
        sta VIC_SPR_Y,y
        lda fs_x,x
        sta VIC_SPR_X,y
        inx
        iny
        iny
        cpy #16
        bne -
        dex
        ldy #7
-       lda fs_ptr,x
        sta SPR_PTRS,y
        lda fs_col,x
        sta VIC_SPR_COL,y
        dex
        dey
        bpl -
        ldx dl_show                     ; the entries of this frame
        stx mux_pos
        beq +
        ldx #1
+       lda dl_n,x
        clc
        adc dl_show
        sta mux_end
        inc frame
        bne +
        inc frame_hi
+       jsr sound_tick
        ldx mux_pos                     ; the first entry's line, or the frame again
        cpx mux_end
        beq _frame
        lda dl_line,x
        sta VIC_RASTER
        lda #<irq_mux
        ldx #>irq_mux
        bne _vec                        ; (always)
_frame  lda #FRAME_LINE
        sta VIC_RASTER
        lda #<irq_frame
        ldx #>irq_frame
_vec    sta IRQ_VEC
        stx IRQ_VEC+1
        pla
        tay
        pla
        tax
        pla
        rti

; the entries due now: each moves a sprite on to its next object
irq_mux
        pha
        txa
        pha
        tya
        pha
        lda #1
        sta VIC_IRQ
        ldx mux_pos
_entry  ldy dl_spr,x                    ; Y = sprite * 2
        lda dl_y,x
        sta VIC_SPR_Y,y
        lda dl_x,x
        sta VIC_SPR_X,y
        lda msb_shadow
        and msb_clear,y
        ora msb_set_tab,x               ; (dl_msb holds the sprite's bit, or 0)
        sta msb_shadow
        sta VIC_SPR_XMSB
        tya
        lsr a
        tay
        lda dl_ptr,x
        sta SPR_PTRS,y
        lda dl_col,x
        sta VIC_SPR_COL,y
        inx
        cpx mux_end
        beq _last
        lda dl_line,x                   ; the next one due already?
        sec
        sbc #2
        cmp VIC_RASTER
        bcc _entry
        beq _entry
        stx mux_pos
        lda dl_line,x
        sta VIC_RASTER
        pla
        tay
        pla
        tax
        pla
        rti
_last   stx mux_pos
        lda #FRAME_LINE
        sta VIC_RASTER
        lda #<irq_frame
        sta IRQ_VEC
        lda #>irq_frame
        sta IRQ_VEC+1
        pla
        tay
        pla
        tax
        pla
        rti

msb_set_tab = dl_msb
msb_clear       .byte $fe,0,$fd,0,$fb,0,$f7,0,$ef,0,$df,0,$bf,0,$7f,0
