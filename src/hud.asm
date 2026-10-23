; =============================================================================
; hud.asm - the top bar (the title and the score, or a message) and the two
; rows under the playfield: wave, funds, health, the countdown; the defender
; to build or the one under the cursor. hud_set marks what changed,
; hud_refresh draws it once a frame.
; =============================================================================

TXT_RED         = 10                    ; light red: the C64's red is dark on black

hud_full
        lda #0
        ldx #HUD_ROW1
        ldy #2
        jsr fill_rows
        jsr hud_labels
        lda #$ff
        sta hud_flags
        ; (on to hud_refresh)

hud_refresh
        lda hud_flags
        and #HUDF_FUNDS                 ; funds changed: the selection (un)affordable?
        beq +
        jsr sel_affordable
        cmp hud_aff
        beq +
        lda #HUDF_INFO
        jsr hud_set
+       lda hud_flags
        bne +
        rts
+       ldx #0
        stx hud_flags
        sta hud_cur
        jsr text_normal
        lsr hud_cur
        bcc +
        jsr hud_wave
+       lsr hud_cur
        bcc +
        jsr hud_info
+       lsr hud_cur
        bcc +
        jsr hud_status
+       lsr hud_cur
        bcc +
        jsr hud_funds
+       lsr hud_cur
        bcc +
        jsr hud_hp
+       lsr hud_cur
        bcc +
        jsr hud_top
+       lsr hud_cur
        bcc +
        jsr hud_score
+       rts

hud_cur         .byte 0
hud_scol        .byte 0                 ; the score's column

; the score again, in the top bar (not under a message)
hud_score
        lda msg_on
        bne +
        lda #1
        sta txt_row
        lda hud_scol
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr hud_at
        lda score
        sta num
        lda score+1
        sta num+1
        lda #5
        jmp print_num
+       rts

; X = letters, Y = background, A = column, txt_row: ready to print
hud_at  sta txt_col
        sta txt_col0
        jmp set_colors

hud_top
        lda msg_on
        beq _title
        lda #COL_BLUE                   ; a message
        ldx #0
        ldy #2
        jsr fill_rows
        ldx #COL_YELLOW
        ldy #COL_BLUE
        jsr set_colors
        lda msg_id1
        ldy #0
        jsr print_id_centered
        lda msg_id2
        cmp #$ff
        bne +
        rts
+       ldx #COL_WHITE
        ldy #COL_BLUE
        jsr set_colors
        lda msg_id2
        ldy #1
        jmp print_id_centered
_title  lda #0
        ldx #0
        ldy #2
        jsr fill_rows
        lda #0
        sta txt_row
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr hud_at
        lda #S_TITLE
        jsr print_id
        lda #1                          ; the score and the lives left
        sta txt_row
        lda #0
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr hud_at
        lda #S_SCORE
        jsr print_id
        lda txt_col
        sta hud_scol
        lda score
        sta num
        lda score+1
        sta num+1
        lda #5
        jsr print_num
        lda #S_LIVES
        jsr print_id
        lda lives
        sta num
        lda #0
        sta num+1
        lda #1
        jmp print_num

hud_wave
        lda #HUD_ROW1
        sta t0
        sta txt_row
        lda #1
        sta t1
        lda #0
        sta t3
        lda #11
        sta t4
        lda #0
        sta t2
        jsr fill_cells
        lda #0
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr hud_at
        lda #S_WAVE
        jsr print_id
        lda #5
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr hud_at
        lda #1
        sta pn_zero
        lda wave_num
        sta num
        lda #0
        sta num+1
        lda #2
        jsr print_num
        lda #G_SLASH
        jsr put_glyph
        lda #NUM_WAVES
        sta num
        lda #0
        sta num+1
        lda #2
        jsr print_num
        lda #0
        sta pn_zero
        rts

hud_labels
        lda #HUD_ROW1
        sta txt_row
        lda #12
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr hud_at
        lda #S_FUNDS
        jsr print_id
        lda #24
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr hud_at
        lda #S_HP
        jmp print_id

hud_funds
        lda #HUD_ROW1
        sta txt_row
        lda #19
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr hud_at
        lda funds
        sta num
        lda funds+1
        sta num+1
        lda #4
        jmp print_num

hud_hp
        lda #HUD_ROW1
        sta txt_row
        ldx #COL_YELLOW
        lda hp
        cmp #30
        bcs +
        ldx #TXT_RED
+       lda #28
        ldy #COL_BLACK
        jsr hud_at
        lda hp
        sta num
        lda #0
        sta num+1
        lda #3
        jmp print_num

hud_status
        lda #HUD_ROW1
        sta t0
        sta txt_row
        lda #1
        sta t1
        lda #33
        sta t3
        lda #7
        sta t4
        lda #0
        sta t2
        jsr fill_cells
        lda paused
        beq +
        lda #33
        ldx #TXT_RED
        ldy #COL_BLACK
        jsr hud_at
        lda #S_PAUSE
        jmp print_id
+       lda wave_state
        beq +
        lda #33
        ldx #COL_LGREEN
        ldy #COL_BLACK
        jsr hud_at
        lda #S_GO
        jmp print_id
+       lda #33
        ldx #COL_LBLUE
        ldy #COL_BLACK
        jsr hud_at
        lda #S_NEXT
        jsr print_id
        lda #1
        sta pn_zero
        lda cd_sec
        sta num
        lda #0
        sta num+1
        lda #2
        jsr print_num
        lda #0
        sta pn_zero
        rts

hud_info
        lda #0
        ldx #HUD_ROW2
        ldy #1
        jsr fill_rows
        lda #HUD_ROW2
        sta txt_row
        jsr cursor_ptr
        bpl _build
        and #$1f                        ; a defender: its name, sell for
        tay
        lda t_type,y
        pha
        lda #0
        ldx #COL_WHITE
        ldy #COL_BLACK
        jsr hud_at
        pla
        pha
        clc
        adc #S_NAME1-1
        jsr print_id
        lda #20
        ldx #COL_YELLOW
        ldy #COL_BLACK
        jsr hud_at
        lda #S_SELL
        jsr print_id
        pla
        tax
        lda tt_sell-1,x
        sta num
        lda #0
        sta num+1
        lda #3
        jmp print_num
_build  jsr sel_affordable              ; the one to build, grey if too dear
        sta hud_aff
        ldx #COL_YELLOW
        cmp #0
        bne +
        ldx #COL_GREY
+       lda #0
        ldy #COL_BLACK
        jsr hud_at
        lda sel_type
        clc
        adc #S_INFO1-1
        jsr print_id
        ; (on to syn_hud)

; the neighbour bonus the selected defender would get on the cursor's cell
syn_hud
        lda sel_type
        ldx cur_c
        ldy cur_r
        jsr syn_find
        bcs +
        rts
+       lda syn_factor-1,x
        pha
        lda syn_text-1,x
        sta t5
        pla
        ldx #TXT_RED                    ; above 16 a bonus, below a penalty
        cmp #17
        bcc +
        jsr syn_count                   ; (grey: SYN_MAX have one already)
        ldx #COL_LGREEN
        cmp #SYN_MAX
        bcc +
        ldx #COL_GREY
+       lda #36
        ldy #COL_BLACK
        jsr hud_at
        lda t5
        jmp print_id
