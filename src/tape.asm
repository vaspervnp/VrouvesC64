; =============================================================================
; tape.asm - the turbo tape loader (the one of the C64 Sugar Byte, made a
; subroutine): the cassette's next block, wherever its header says. Used by
; the tape's boot file (the loading picture, the game) and by the game on
; tape (the ending, which follows on the tape: leave it running).
;
; Pulses on the cassette line (CIA 1 FLAG): a short one (216 cycles) a 0, a
; long one (432) a 1, told apart by a one-shot timer of TAPE_THRESHOLD cycles
; started at every pulse. Most significant bit first.
;   pilot $aa ..., sync $a5 $5a, load address, end address (past the last
;   byte), entry, the bytes, an XOR checksum (tools/mktap.py).
; Interrupts off; the border flickers with the bits.
; =============================================================================

TAPE_THRESHOLD  = 324
tape_ptr        = $fb                   ; (the KERNAL's: the tape has no use for it)

; -> the block loaded, tape_head = its load, end, entry; C set: a bad checksum
tape_load
        sei
        lda #$7f                        ; no CIA interrupts
        sta $dc0d
        lda $dc0d
        lda $00                         ; the motor on
        ora #$20
        sta $00
        lda $01
        and #$df
        sta $01
        lda #<TAPE_THRESHOLD
        sta $dc04
        lda #>TAPE_THRESHOLD
        sta $dc05
_sync   jsr _bit                        ; bit by bit until $a5
        lda tape_shift
        cmp #$a5
        bne _sync
        jsr _byte
        cmp #$5a
        bne _sync
        ldx #0                          ; the header: 6 bytes
-       jsr _byte
        sta tape_head,x
        inx
        cpx #6
        bne -
        lda tape_head
        sta tape_ptr
        lda tape_head+1
        sta tape_ptr+1
        lda #0
        sta tape_sum
        ldy #0
_data   jsr _byte
        sta (tape_ptr),y
        eor tape_sum
        sta tape_sum
        inc tape_ptr
        bne +
        inc tape_ptr+1
+       lda tape_ptr
        cmp tape_head+2
        lda tape_ptr+1
        sbc tape_head+3
        bcc _data
        jsr _byte                       ; the checksum: 0 when right
        eor tape_sum
        sta tape_sum
        lda $01                         ; the motor off
        ora #$20
        sta $01
        lda #0
        sta $d020
        lda tape_sum
        cmp #1                          ; C set: wrong
        rts

; -> A = the next byte
_byte   lda #1                          ; a marker bit: 8 shifts and it falls out
        sta tape_shift
-       jsr _bit
        bcc -
        lda tape_shift
        rts

; one bit into tape_shift (C = the bit that falls out)
_bit    lda #$10
-       bit $dc0d                       ; a pulse
        beq -
        lda $dc0e                       ; the timer still running: a short pulse, 0
        eor #1
        lsr a
        rol tape_shift
        lda #$19                        ; one-shot, loaded again, started
        sta $dc0e
        lda tape_shift
        sta $d020
        rts

tape_shift      .byte 0
tape_sum        .byte 0
tape_head       .fill 6
