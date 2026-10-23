; =============================================================================
; disk.asm - files through the KERNAL: the high scores (read at the start,
; written after a new entry) and the ending's picture. The game leaves the
; KERNAL's memory ($90-$3ff) alone, so it only has to be banked in, with
; the interrupts and the sprites off, for as long as it works.
; =============================================================================

SETMSG          = $ff90
SETLFS          = $ffba
SETNAM          = $ffbd
OPEN            = $ffc0
CLOSE           = $ffc3
LOAD            = $ffd5
SAVE            = $ffd8
CLRCHN          = $ffcc
LAST_DEVICE     = $ba

; the KERNAL in, the game's interrupts and sprites out
disk_begin
        sei
        lda #0
        sta VIC_IRQ_MASK
        sta VIC_SPR_ENA
        lda #1
        sta VIC_IRQ
        lda #0                          ; the SID quiet
        sta SID+4
        sta SID+11
        sta SID+18
        lda #$36
        sta $01
        lda #0
        jsr SETMSG
        lda LAST_DEVICE                 ; the device the game came from
        cmp #8
        bcs +
        lda #8
        sta LAST_DEVICE
+       rts

; and back: the RAM in, the interrupts on
disk_end
        php
        pha
        jsr CLRCHN
        lda #$35
        sta $01
        lda #$7f                        ; (the KERNAL may have started its timer)
        sta CIA1_ICR
        lda CIA1_ICR
        lda #1
        sta VIC_IRQ
        sta VIC_IRQ_MASK
        pla
        plp
        cli
        rts

; A = name length, X/Y = name, dst = where to -> C set on an error
disk_load
        jsr SETNAM
        lda #1
        ldx LAST_DEVICE
        ldy #0                          ; to dst, not the file's own address
        jsr SETLFS
        lda #0
        ldx dst
        ldy dst+1
        jsr LOAD
        rts

; the table from the disk, if it is there; the built in one if not
hs_load
        jsr disk_begin
        lda #<hs_file_buf
        sta dst
        lda #>hs_file_buf
        sta dst+1
        lda #HS_NAME_LEN
        ldx #<hs_fname
        ldy #>hs_fname
        jsr disk_load
        jsr disk_end
        bcs _keep
        ldx #3                          ; "VRV1"?
-       lda hs_file_buf,x
        cmp hs_magic,x
        bne _keep
        dex
        bpl -
        ldx #HS_N*5-1
-       lda hs_file_buf+4,x
        sta hs_table,x
        dex
        bpl -
_keep   rts

; the table to the disk: the old file scratched, the new one saved
hs_save
        ldx #3
-       lda hs_magic,x
        sta hs_file_buf,x
        dex
        bpl -
        ldx #HS_N*5-1
-       lda hs_table,x
        sta hs_file_buf+4,x
        dex
        bpl -
        jsr disk_begin
        lda #HS_SCRATCH_LEN             ; OPEN 15,dev,15,"S0:VR-HISCORE": CLOSE 15
        ldx #<hs_scratch
        ldy #>hs_scratch
        jsr SETNAM
        lda #15
        ldx LAST_DEVICE
        ldy #15
        jsr SETLFS
        jsr OPEN
        lda #15
        jsr CLOSE
        lda #HS_NAME_LEN
        ldx #<hs_fname
        ldy #>hs_fname
        jsr SETNAM
        lda #1
        ldx LAST_DEVICE
        ldy #0
        jsr SETLFS
        lda #<hs_file_buf
        sta ptr
        lda #>hs_file_buf
        sta ptr+1
        lda #ptr
        ldx #<hs_file_end
        ldy #>hs_file_end
        jsr SAVE
        jmp disk_end

hs_fname        .text "VR-HISCORE"
HS_NAME_LEN     = * - hs_fname
hs_scratch      .text "S0:VR-HISCORE"
HS_SCRATCH_LEN  = * - hs_scratch
hs_magic        .text "VRV1"
hs_file_buf     .fill 4 + HS_N*5
hs_file_end

; the feast at the school: the picture from the disk, until fire
ending_show
        jsr wait_frame
        jsr shots_erase
        lda #0
        sta ob_n
        jsr mux_build_wait
        jsr wait_frame
        lda #T_LOADING                  ; the screen tells what is going on
        ldx #$ff
        jsr banner_show
        jsr disk_begin
        lda #<SCREEN                    ; screen RAM, the colour RAM's (behind it), bg
        sta dst
        lda #>SCREEN
        sta dst+1
        lda #END_SCR_LEN
        ldx #<end_scr_name
        ldy #>end_scr_name
        jsr disk_load
        bcs _fail
        lda #<BITMAP                    ; the bitmap, on show as it comes
        sta dst
        lda #>BITMAP
        sta dst+1
        lda #END_BMP_LEN
        ldx #<end_bmp_name
        ldy #>end_bmp_name
        jsr disk_load
_fail   php
        ldx #0                          ; the colour RAM
-       lda SCREEN+1000,x
        sta $d800,x
        lda SCREEN+1000+250,x
        sta $d800+250,x
        lda SCREEN+1000+500,x
        sta $d800+500,x
        lda SCREEN+1000+750,x
        sta $d800+750,x
        inx
        cpx #250
        bne -
        lda SCREEN+2000
        sta VIC_BG0
        plp
        jsr disk_end
        lda #TUNE_MENU
        sta snd_want
-       jsr wait_frame
        jsr kbd_update
        jsr fire_hit
        bcc -
        lda #BG_COLOUR
        sta VIC_BG0
        rts

end_scr_name    .text "VR-ENDSCR"
END_SCR_LEN     = * - end_scr_name
end_bmp_name    .text "VR-ENDBMP"
END_BMP_LEN     = * - end_bmp_name
