; =============================================================================
; title.asm - the title screen: the title, the difficulty, and pages that
; change every 9 seconds (or with right): a scene with the keys, the story,
; the defenders, the invaders, the high scores.
;
;   rows 1-2 the title (twice the size), 3 the difficulty, 4 a line,
;   rows 5-20 the page, 21 a line, 22-24 start, language, credits
; =============================================================================

TITLE_PAGE_FRAMES = 450
TITLE_PAGES     = 5
HS_PAGE         = 4
PAGE_ROW        = 5

title_screen
        jsr screen_off
        lda #0
        sta ob_n
        jsr mux_build_wait
        lda #BG_COLOUR
        sta VIC_BG0
        lda #TUNE_MENU
        sta snd_want
        jsr clear_screen
        jsr title_static
        lda #0
        sta tpage
        jsr title_page
        jsr screen_on
        jsr hs_check                    ; a score for the table: the name, the table
        lda #0
        sta ttimer
        sta ttimer+1
_loop   jsr wait_frame
title_frame = *                         ; (tests stop here)
        jsr kbd_update
        lda #K_L
        jsr key_hit
        bcc +
        lda lang
        eor #1
        sta lang
        jsr title_static
        jsr title_page
+       lda #K_D
        jsr key_hit
        bcc +
        lda difficulty
        clc
        adc #1
        and #3
        sta difficulty
        jsr title_dif
+       lda #K_M
        jsr key_hit
        bcc +
        jsr toggle_music
+       lda #C_RIGHT
        jsr key_hit
        bcs _next
        lda #J_RIGHT
        jsr key_hit
        bcs _next
        jsr fire_hit
        bcs _start
        inc ttimer
        bne +
        inc ttimer+1
+       lda ttimer
        cmp #<TITLE_PAGE_FRAMES
        lda ttimer+1
        sbc #>TITLE_PAGE_FRAMES
        bcc _loop
_next   lda #0
        sta ttimer
        sta ttimer+1
        inc tpage
        lda tpage
        cmp #TITLE_PAGES
        bcc +
        lda #0
        sta tpage
+       jsr title_page
        jmp _loop
_start  lda #0                          ; a new game: no points, the lives
        sta score                       ; of the difficulty
        sta score+1
        sta score_chk
        sta score_chk+1
        ldx difficulty
        lda dif_lives,x
        sta lives
        rts

dif_lives       .byte 3,2,0,4
tpage           .byte 0
ttimer          .word 0

title_static
        lda #0
        ldx #0
        ldy #5
        jsr fill_rows
        lda #0
        ldx #21
        ldy #4
        jsr fill_rows
        ldx #4                          ; the two orange lines
        ldy #6
        lda #COL_ORANGE
        jsr hline
        ldx #4
        ldy #7
        lda #COL_ORANGE
        jsr hline
        ldx #21
        ldy #0
        lda #COL_ORANGE
        jsr hline
        ldx #21
        ldy #1
        lda #COL_ORANGE
        jsr hline
        jsr text_big                    ; the title, in the active language only
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr set_colors
        lda #S_TITLE
        jsr get_str
        jsr str_len
        lda t5
        asl a
        sta t5
        lda #40
        sec
        sbc t5
        lsr a
        tax
        ldy #1
        jsr set_at
        lda #S_TITLE
        jsr print_id
        jsr text_normal
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr set_colors
        lda #T_START
        ldy #22
        jsr print_id_centered
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr set_colors
        lda #S_LANGHINT
        ldy #23
        jsr print_id_centered
        ldx #COL_GREY
        ldy #COL_BLACK
        jsr set_colors
        lda #T_CREDIT
        ldy #24
        jsr print_id_centered
        ; (on to title_dif)

; under the title: the difficulty and its lives
title_dif
        lda #0
        ldx #3
        ldy #1
        jsr fill_rows
        jsr text_normal
        ldx #COL_LBLUE
        ldy #COL_BLACK
        jsr set_colors
        lda difficulty
        clc
        adc #T_DIF0
        ldy #3
        jmp print_id_centered

title_page
        lda #0                          ; the page's rows cleared
        sta ob_n
        jsr mux_build_wait
        lda #0
        ldx #PAGE_ROW
        ldy #16
        jsr fill_rows
        jsr text_normal
        lda tpage
        bne +
        jmp tp_keys
+       cmp #1
        bne +
        jmp tp_story
+       cmp #2
        beq tp_defenders
        cmp #3
        beq tp_invaders
        jmp hs_show

tp_defenders
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr set_colors
        lda #T_DEFHDR
        ldy #PAGE_ROW
        jsr print_id_centered
        ldx #0
        lda #7
        bne tp_cast                     ; (always)

tp_invaders
        ldx #TXT_RED
        ldy #COL_BLACK
        jsr set_colors
        lda #T_ENEHDR
        ldy #PAGE_ROW
        jsr print_id_centered
        ldx #6
        lda #7

; X = the first picture, A = its row: the pictures and their texts
tp_cast
        stx tc_i
        sta tc_row
-       ldx tc_i
        jsr draw_icon
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr set_colors
        ldx #5
        ldy tc_row
        jsr set_at
        ldx tc_i
        lda cast_text,x
        jsr print_id
        lda tc_row
        clc
        ldx tc_i
        adc cast_step,x
        sta tc_row
        inc tc_i
        lda tc_i
        cmp #6
        beq +
        cmp #9
        bne -
+       rts

tc_i            .byte 0
tc_row          .byte 0
cast_text       .byte T_CAST1,T_CAST2,T_CAST3,T_CAST4,T_CAST5,T_CAST6,T_ENE1,T_ENE2,T_ENE3
cast_step       .byte 2,2,2,2,2,2,3,3,3

; X = picture (icons: 3 x 2 cells), tc_row: at columns 1-3
draw_icon
        lda icon_lo,x
        sta src
        lda icon_hi,x
        sta src+1
        lda #0
        sta t3                          ; the picture's cell row
_row    ldx #1
        lda tc_row
        clc
        adc t3
        tay
        jsr cell_addr
        ldy #23                         ; 3 cells of bitmap
-       lda (src),y
        sta (bmp),y
        dey
        bpl -
        lda t3
        beq +
        lda #3                          ; screen and colour: 3 on, the second row
+       sta t4
        ldx #0
-       txa
        clc
        adc t4
        adc #48
        sta t5
        tay
        lda (src),y                     ; screen RAM
        pha
        lda t5
        adc #6
        tay
        lda (src),y                     ; colour RAM
        stx t5
        ldy t5
        sta (colp),y
        pla
        sta (scrp),y
        inx
        cpx #3
        bne -
        lda t3
        bne _done
        inc t3
        lda src                         ; the second row's bitmap: 24 on (and the
        clc                             ; screen and colour 24 back, hence 48-24+3)
        adc #24
        sta src
        bcc +
        inc src+1
+       lda #<-24+3
        sta t4
        jmp _row2
_done   rts
_row2   ldx #1
        lda tc_row
        clc
        adc #1
        tay
        jsr cell_addr
        ldy #23
-       lda (src),y
        sta (bmp),y
        dey
        bpl -
        ldx #0
-       txa
        clc
        adc #48-24+3
        tay
        lda (src),y
        pha
        tya
        clc
        adc #6
        tay
        lda (src),y
        stx t5
        ldy t5
        sta (colp),y
        pla
        sta (scrp),y
        inx
        cpx #3
        bne -
        rts

icon_lo         .byte <(icons + range(9) * 60)
icon_hi         .byte >(icons + range(9) * 60)

tp_keys
        lda #<title_art_bmp             ; the scene, packed
        sta src
        lda #>title_art_bmp
        sta src+1
        lda #<(BITMAP+PAGE_ROW*320)
        sta dst
        lda #>(BITMAP+PAGE_ROW*320)
        sta dst+1
        jsr lz_unpack
        lda #<title_art_scr
        sta src
        lda #>title_art_scr
        sta src+1
        lda #<(SCREEN+PAGE_ROW*40)
        sta dst
        lda #>(SCREEN+PAGE_ROW*40)
        sta dst+1
        jsr lz_unpack
        lda #<title_art_col             ; colour RAM: through a buffer (it
        sta src                         ; cannot be read back whole)
        lda #>title_art_col
        sta src+1
        lda #<e_type
        sta dst
        lda #>e_type
        sta dst+1
        jsr lz_unpack
        ldx #0
-       lda e_type,x
        sta $d800+PAGE_ROW*40,x
        lda e_type+256,x
        sta $d800+PAGE_ROW*40+256,x
        lda e_type+384,x
        sta $d800+PAGE_ROW*40+384,x
        inx
        bne -
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr set_colors
        ldx #12
        ldy #13
        jsr set_at
        lda #T_CTRL
        jsr print_id
        ldx #30
        ldy #13
        jsr set_at
        lda #T_CTRL2
        jmp print_id

tp_story
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr set_colors
        ldx #0
        ldy #PAGE_ROW+1
        jsr set_at
        lda #T_STORY
        jmp print_id
