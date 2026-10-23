; =============================================================================
; lz.asm - unpacks tools/lz.py's streams: $00-$7f n+1 literal bytes, $80-$fe
; a copy of n-$7e bytes from 'offset' (two bytes) back in the output, $ff
; the end.
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
_copy   sbc #$7e                        ; (C set) the length
        tax
        jsr _get
        sta t0
        jsr _get
        sta t1
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
