; =============================================================================
; lz.asm - unpacks tools/lz.py's streams: $00-$7f n+1 literal bytes, $80-$bf
; a copy of n-$7e bytes from 1 + the next byte back in the output, $c0-$fe a
; copy of n-$be bytes from 'offset' (two bytes) back, $ff the end.
; =============================================================================

; src = packed, dst = where to
lz_unpack
        ldy #0
_tok    jsr _get
        cmp #$ff
        beq _end
        cmp #$80
        bcs _copy
        tax
        inx
-       jsr _get
        sta (dst),y
        inc dst
        bne +
        inc dst+1
+       dex
        bne -
        beq _tok                        ; (always)
_copy   sta t2                          ; the length
        and #$3f
        clc
        adc #2
        tax
        jsr _get
        sta t0
        lda #0
        sta t1
        bit t2
        bvs _far
        inc t0                          ; (near: offset - 1, up to 256)
        bne _go
        inc t1
        bne _go                         ; (always)
_far    jsr _get
        sta t1
_go
        lda dst                         ; ptr = dst - offset
        sec
        sbc t0
        sta ptr
        lda dst+1
        sbc t1
        sta ptr+1
-       lda (ptr),y
        sta (dst),y
        inc ptr
        bne +
        inc ptr+1
+       inc dst
        bne +
        inc dst+1
+       dex
        bne -
        beq _tok                        ; (always)
_end    rts
_get    lda (src),y
        inc src
        bne +
        inc src+1
+       rts
