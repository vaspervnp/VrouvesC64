; =============================================================================
; boot.asm - the file to LOAD"VROUVES",8 and RUN: the loading picture
; (tools/mkdata64.py, assets/vrouves.jpeg) on show while the KERNAL loads the
; game (VR-GAME, $0801-), which then starts at GAME_START.
;
; The picture goes to VIC bank 3 (bitmap $e000, screen $cc00), out of the
; game's way; the loader itself sits at $c800.
; =============================================================================

        .include "hw.inc"

SETMSG          = $ff90
SETLFS          = $ffba
SETNAM          = $ffbd
LOAD            = $ffd5
LAST_DEVICE     = $ba
PIC_BMP         = $e000
PIC_SCR         = $cc00
LOADER          = $c800

        * = $0801
        .word (+), 10
        .null $9e, format("%d", start)
+       .word 0

start
        sei
        lda #$7f                        ; the KERNAL's timer interrupt off: the
        sta CIA1_ICR                    ; loader needs no interrupts
        lda CIA1_ICR
        lda #$0b                        ; blank while the picture is copied
        sta VIC_CTRL1
        lda #0
        sta VIC_BORDER
        sta VIC_SPR_ENA
        ldx #0                          ; the bitmap: 8000 bytes, under the KERNAL
-       .for i = 0, i < 32, i += 1
        lda picture+i*250,x
        sta PIC_BMP+i*250,x
        .endfor
        inx
        cpx #250
        beq +
        jmp -
+       ldx #0                          ; screen and colour RAM
-       .for i = 0, i < 4, i += 1
        lda picture+8000+i*250,x
        sta PIC_SCR+i*250,x
        lda picture+9000+i*250,x
        sta $d800+i*250,x
        .endfor
        inx
        cpx #250
        bne -
        lda picture+10000
        sta VIC_BG0
        lda CIA2_PRA                    ; bank 3, screen $cc00, bitmap $e000
        and #$fc
        sta CIA2_PRA
        lda #$38
        sta VIC_MEM
        lda #$18
        sta VIC_CTRL2
        lda #$3b
        sta VIC_CTRL1
        ldx #loader_end-loader-1
-       lda loader,x
        sta LOADER,x
        dex
        bpl -
        jmp LOADER

loader
        .logical LOADER
        lda #0
        jsr SETMSG
        lda LAST_DEVICE
        cmp #8
        bcs +
        lda #8
+       tax
        lda #1
        ldy #1                          ; to the file's own address
        jsr SETLFS
        lda #game_name_end-game_name
        ldx #<game_name
        ldy #>game_name
        jsr SETNAM
        lda #0
        jsr LOAD
        bcs _fail
        jmp GAME_START
_fail   inc VIC_BORDER                  ; no game on the disk: the border says so
        jmp _fail
game_name       .text "VR-GAME"
game_name_end
        .here
loader_end

picture .binary "../build/splash.bin"
