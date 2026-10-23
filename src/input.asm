; =============================================================================
; input.asm - the keyboard matrix and the joysticks, once a frame.
;
; keys+0..7 = the matrix rows (a bit set = a key down: key code row*8+bit),
; keys+8 = the joysticks (J_*), keys+9 = the cursor keys as four (C_*: up
; and left with a shift). kold is the pass before: key_hit is a new press.
; The game's loop takes a pass every few frames and reads the keys every
; frame between (kbd_scan): a pass sees what was down at any time since.
; A joystick in use hides the keyboard (its lines would show up as keys).
; Tests write test_keys (a key code, $ff = none) instead of pressing.
; =============================================================================

; a pass: the keys down since the last one
kbd_update
        jsr kbd_scan
        ldx #KEY_ROWS-1
-       lda keys,x
        sta kold,x
        lda kacc,x
        sta keys,x
        lda #0
        sta kacc,x
        dex
        bpl -
        rts

; the keys now, added to kacc
kbd_scan
        jsr _read
        ldx #KEY_ROWS-1
-       lda ktmp,x
        ora kacc,x
        sta kacc,x
        dex
        bpl -
        rts
_read   ldx #KEY_ROWS-1
        lda #0
-       sta ktmp,x
        dex
        bpl -
        lda test_keys
        bmi _real
        lsr a                           ; a test's key
        lsr a
        lsr a
        tax
        lda test_keys
        and #7
        tay
        lda bit_tab,y
        sta ktmp,x
        rts
_real   lda #$ff                        ; no row: the joysticks alone
        sta CIA1_PRA
        lda CIA1_PRA                    ; port 2
        and CIA1_PRB                    ; port 1
        eor #$ff
        and #$1f
        sta ktmp+8
        bne _done
        ldx #7
        lda #$7f
        sta t0
-       lda t0
        sta CIA1_PRA
        lda CIA1_PRB
        eor #$ff
        sta ktmp,x
        sec
        ror t0
        dex
        bpl -
        lda #$ff
        sta CIA1_PRA
        lda ktmp+1                      ; a shift: left (row 1 bit 7), right (row 6 bit 4)
        and #$80
        sta t0
        lda ktmp+6
        and #$10
        ora t0
        sta t0
        lda #0
        sta t1
        lda ktmp                        ; CRSR right (bit 2), down (bit 7)
        and #$04
        beq +
        lda #8                          ; C_RIGHT
        ldx t0
        beq ++
        lda #4                          ; C_LEFT
+
+       sta t1
        lda ktmp
        and #$80
        beq +
        lda #2                          ; C_DOWN
        ldx t0
        beq ++
        lda #1                          ; C_UP
+
+       ora t1
        sta ktmp+9
_done   rts

; A = key code -> C set if down now.  Preserves X, Y.
key_down
        sty t7
        pha
        and #7
        tay
        pla
        pha
        lsr a
        lsr a
        lsr a
        sty t6
        tay
        lda keys,y
        ldy t6
        and bit_tab,y
        ldy t7
        cmp #1                          ; C = not zero
        pla
        rts

; A = key code -> C set if pressed in this frame (down now, not before)
key_hit
        sty t7
        pha
        and #7
        tay
        lda bit_tab,y
        sta t6
        pla
        pha
        lsr a
        lsr a
        lsr a
        tay
        lda kold,y
        eor #$ff
        and keys,y
        and t6
        ldy t7
        cmp #1
        pla
        rts

; C set if SPACE, RETURN or fire was pressed in this frame
fire_hit
        lda #K_SPACE
        jsr key_hit
        bcs +
        lda #K_RETURN
        jsr key_hit
        bcs +
        lda #J_FIRE
        jsr key_hit
+       rts

; C set if anything was pressed in this frame
any_hit
        ldx #KEY_ROWS-1
-       lda kold,x
        eor #$ff
        and keys,x
        bne +
        dex
        bpl -
        clc
        rts
+       sec
        rts
