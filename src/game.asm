; =============================================================================
; game.asm - a stage: the loop, the input, the waves, the invaders, the
; defenders, their shots and the effects. The rules are the CPC's, tick for
; tick: the logic runs at 25 Hz (a tick every two frames), whatever the
; drawing takes.
; =============================================================================

        .if DEBUG != 0
START_FUNDS     = 3000
        .else
START_FUNDS     = 120
        .endif

; --- tables ---------------------------------------------------------------------
; invaders (drone, guard, tank): health, health a wave, speed, armour, reward,
; the damage it does at the building
et_hp           .byte 6,16,50
et_hpw          .byte 3,8,19
et_spd          .byte 20,9,7
et_arm          .byte 0,2,4
et_rew          .byte 3,4,10
et_dmg          .byte 4,8,20
; defenders (cretan, yiayia, bride, psssst, cauldron, baker)
tt_cost         .byte 35,50,70,80,110,60
tt_range        .byte 30,18,28,36,22,34
tt_cd           .byte 18,22,6,10,32,36
tt_dmg          .byte 6,14,4,5,8,16
tt_air          .byte 1,0,1,1,0,1
tt_proj         .byte PT_BULLET,0,PT_PISTOL,PT_LASER,0,PT_DAKOS
tt_sfx          .byte SFX_RIFLE,SFX_BASH,SFX_PISTOL,SFX_LASER,SFX_PUFF,SFX_THROW
tt_sell         .byte 17,25,35,40,55,30
; the neighbour bonus: partner, damage factor in 16ths, its text
syn_partner     .byte 0,TT_BAKER,TT_CRETAN,TT_CRETAN,0,TT_CRETAN
syn_factor      .byte 0,19,24,13,0,8
syn_text        .byte 0,T_SYN20P,T_SYN50P,T_SYN20M,0,T_SYN50M
; shots: speed across (pixels), down (lines)
pr_sx           .byte 6,7,10,3
pr_sy           .byte 9,10,15,5
; effects: frames a and b, lifetime
fx_a            .byte SPR_SPARK_A,SPR_PUFF_A,SPR_BASH_A,SPR_POOF_A,SPR_BOOM_A,SPR_ZAP_A
fx_b            .byte SPR_SPARK_B,SPR_PUFF_B,SPR_BASH_B,SPR_POOF_B,SPR_BOOM_B,SPR_SPARK_B
fx_life         .byte 6,12,8,10,12,6
sel_keys        .byte K_1,K_2,K_3,K_4,K_5,K_6
sq_lo           .byte <(range(64) * range(64))
sq_hi           .byte >(range(64) * range(64))

; =============================================================================
; the loop
; =============================================================================
game_run
        jsr game_init
_loop   lda frame                       ; a new frame (a slow pass has had one)
        cmp pass_frame
        beq _loop
        sta pass_frame
        jsr kbd_update
        jsr shots_erase
        jsr handle_input
        lda quit
        beq +
        rts
+       lda frame                       ; the ticks due: one per two frames gone
        tax
        sec
        sbc frame_seen
        stx frame_seen
        clc
        adc frame_acc
        tax
        and #1
        sta frame_acc
        txa
        lsr a
        cmp #3                          ; at most two: under a heavy load the
        bcc +                           ; game slows a little rather than jump
        lda #0
        sta frame_acc
        lda #2
+       sta ticks_due
        lda paused
        bne _draw
-       lda ticks_due
        beq _draw
        jsr game_tick
        dec ticks_due
        lda game_over
        beq -
_draw   jsr flag_tick
        jsr shots_draw
        jsr hud_refresh
        jsr build_sprites
frame_done = *                          ; (tests stop here)
        lda game_over
        beq _loop
        jmp end_game

game_tick
        lda #TARGET_BUDGET
        sta tr_budget
        jsr wave_update
        jsr update_enemies
        jsr update_towers
        jsr update_projs
        jsr update_fx
        jmp banner_tick

; the stage's data: paths, tiles, flag, defenders
stage_load
        ldx stage
        lda st_pg_lo,x
        sta path_g
        lda st_pg_hi,x
        sta path_g+1
        lda st_pa_lo,x
        sta path_a
        lda st_pa_hi,x
        sta path_a+1
        lda st_flag_x,x
        sta flag_x
        lda st_flag_y,x
        sta flag_y
        lda st_lmap_lo,x
        sta ptr
        lda st_lmap_hi,x
        sta ptr+1
        lda st_nltiles,x
        sta t0
        ldx #0
-       ldy #0
        lda (ptr),y
        sta tad_lo,x
        iny
        lda (ptr),y
        sta tad_hi,x
        lda ptr
        clc
        adc #2
        sta ptr
        bcc +
        inc ptr+1
+       inx
        cpx t0
        bne -
        rts

game_init
        jsr screen_off
        lda #0                          ; nothing on show
        sta ob_n
        jsr mux_build_wait
        ldx stage                       ; the maps as the stage starts:
        lda st_tmap_lo,x                ; sacks back, no defenders
        sta src
        lda st_tmap_hi,x
        sta src+1
        lda #<tmap
        sta dst
        lda #>tmap
        sta dst+1
        jsr copy_cells
        ldx stage
        lda st_cmap_lo,x
        sta src
        lda st_cmap_hi,x
        sta src+1
        lda #<cmap
        sta dst
        lda #>cmap
        sta dst+1
        jsr copy_cells
        jsr clear_entities              ; everything cleared
        lda #0
        ldx #GV_END-GV_START-1
-       sta GV_START,x
        dex
        bpl -
        sta sv_n
        lda #<START_FUNDS
        sta funds
        lda #>START_FUNDS
        sta funds+1
        lda #100
        sta hp
        lda #FIRST_COUNTDOWN
        sta cd_sec
        lda #25
        sta cd_sub
        lda #7
        sta cur_c
        lda #3
        sta cur_r
        lda #1
        sta sel_type
        lda frame
        sta frame_seen
        ldx stage
        lda st_unlock,x
        sta unlock
        jsr clear_screen
        jsr compose_all
        lda #B_STAGE
        ldx #B_CALL
        jsr msg_show
        .if DEBUG != 0
        lda #DEBUG-1                    ; -D DEBUG=n: at wave n, every defender
        sta wave_num
        lda #$3f
        sta unlock
        .else
        ldx stage                       ; the defender this stage brings
        lda st_ann1,x
        cmp #$ff
        beq +
        pha
        lda st_ann2,x
        tax
        pla
        jsr banner_show
        lda #125                        ; for five seconds
        sta ban_timer
+
        .endif
        jsr hud_full
        lda #TUNE_GAME
        sta snd_want
        jmp screen_on

; the invaders, defenders, shots and effects: none
clear_entities
        ldx #0
        lda #0
-       sta e_type,x
        sta e_type+256,x
        inx
        bne -
        ldx #ENT_END-e_type-512-1
-       sta e_type+512,x
        dex
        cpx #$ff
        bne -
        rts
        .cerror ENT_END-e_type <= 512 || ENT_END-e_type > 768, "clear_entities: the size"

; src -> dst: NCELLS bytes
copy_cells
        ldy #0
-       lda (src),y
        sta (dst),y
        iny
        bne -
        inc src+1
        inc dst+1
-       lda (src),y
        sta (dst),y
        iny
        cpy #NCELLS-256
        bne -
        rts

; won or lost: the banner, then fire
end_game
        jsr clear_entities              ; no invaders, shots or effects on show
        jsr wait_frame
        jsr shots_erase
        jsr kbd_update
        lda #B_WIN
        ldx game_over
        cpx #1
        beq +
        lda #B_LOSE
+       ldx #B_SPACE
        jsr banner_show
        lda #SFX_WAVE
        jsr sfx_play
        lda #40
        sta end_wait
_l      jsr wait_frame
        jsr kbd_update
        jsr hud_refresh
        jsr build_sprites
        lda end_wait
        beq +
        dec end_wait
        jmp _l
+       jsr fire_hit
        bcc _l
        rts

; =============================================================================
; input
; =============================================================================
handle_input
        jsr any_down                    ; nothing down: no work
        bcs _keys
        lda #0
        sta rep_t
        rts
_keys   lda #K_L
        jsr key_hit
        bcc +
        jsr toggle_lang
+       lda #K_M
        jsr key_hit
        bcc +
        jsr toggle_music
+       lda #K_H
        jsr key_hit
        bcc +
        jsr toggle_pause
+       lda #K_STOP
        jsr key_hit
        bcs _stop
        lda #K_ARROW
        jsr key_hit
        bcc _ne
_stop   lda paused
        beq +
        lda #1                          ; RUN/STOP while paused: back to the title
        sta quit
        rts
+       jsr toggle_pause
_ne     lda paused
        beq +
        rts
+       jsr cursor_input
        ldx #0
-       lda sel_keys,x                  ; 1-6: a defender this stage has
        jsr key_hit
        bcc _nk
        lda unlock
        and bit_tab,x
        beq _nk
        inx
        stx sel_type
        dex
        lda #HUDF_INFO
        jsr hud_set
_nk     inx
        cpx #6
        bne -
        jsr fire_hit
        bcc +
        jsr try_build
+       lda #K_S
        jsr key_hit
        bcc +
        jsr try_sell
+       lda #K_DEL
        jsr key_hit
        bcc +
        jsr try_sell
+       lda #K_N
        jsr key_hit
        bcc +
        jsr call_wave_now
+       rts

; C set if any key or joystick is down
any_down
        ldx #KEY_ROWS-1
-       lda keys,x
        ora kold,x
        bne +
        dex
        bpl -
        clc
        rts
+       sec
        rts

toggle_lang
        lda lang
        eor #1
        sta lang
        jsr hud_full
        lda ban_on
        beq +
        jmp banner_draw
+       rts

toggle_music
        lda mus_on
        eor #1
        sta mus_on
        rts

toggle_pause
        lda paused
        eor #1
        sta paused
        beq _resume
        lda #B_PAUSE
        ldx #B_PAUSE2
        jsr banner_show
        jmp +
_resume jsr banner_clear
+       lda #HUDF_STATUS
        jmp hud_set

; the cursor: up, down, left, right (held: repeated)
cursor_input
        lda keys+9                      ; the cursor keys: bits up, down, left, right
        ora keys+8                      ; the joysticks: the same bits
        and #15
        sta t0
        ldx #3
-       lda qaop_keys,x
        jsr key_down
        bcc +
        lda t0
        ora bit_tab,x
        sta t0
+       dex
        bpl -
        lda t0
        bne _held
        sta rep_t
        rts
_held   lda rep_t
        beq _first
        dec rep_t
        beq +
        rts
+       lda #REP_NEXT
        jmp _go
_first  lda #REP_FIRST
_go     sta rep_t
        lsr t0                          ; up
        bcc +
        lda cur_r
        beq +
        dec cur_r
+       lsr t0                          ; down
        bcc +
        lda cur_r
        cmp #NROW-1
        beq +
        inc cur_r
+       lsr t0                          ; left
        bcc +
        lda cur_c
        beq +
        dec cur_c
+       lsr t0                          ; right
        bcc +
        lda cur_c
        cmp #NCOL-1
        beq +
        inc cur_c
+       lda #HUDF_INFO
        jsr hud_set
        lda #SFX_MOVE
        jmp sfx_play

qaop_keys       .byte K_Q, K_A, K_O, K_P

; cells are addressed through cell_ptr: X = col, Y = row -> ptr = &cmap[..],
; ptr2 = &tmap[..], Y = 0
cell_ptr
        txa
        clc
        adc mul20_lo,y
        sta ptr
        lda mul20_hi,y
        adc #0
        sta ptr+1
        lda ptr
        clc
        adc #<tmap
        sta ptr2
        lda ptr+1
        adc #>tmap
        sta ptr2+1
        lda ptr
        clc
        adc #<cmap
        sta ptr
        lda ptr+1
        adc #>cmap
        sta ptr+1
        ldy #0
        rts

mul20_lo        .byte <range(0, NROW*20, 20)
mul20_hi        .byte >range(0, NROW*20, 20)

; the cursor's cell -> ptr (cmap), ptr2 (tmap), A = cmap, Y = 0
cursor_ptr
        ldx cur_c
        ldy cur_r
        jsr cell_ptr
        lda (ptr),y
        rts

; C set if the selected defender cannot go on the cursor's cell
can_build
        jsr cursor_ptr
        beq _ok                         ; grass
        cmp #2
        bne _no                         ; road, building, a defender
        lda sel_type                    ; blocked: only psssst hovers there
        cmp #TT_PSSSST
        bne _no
_ok     clc
        rts
_no     sec
        rts

; A = 1 if the selected defender can be paid for
sel_affordable
        ldx sel_type
        lda funds+1
        bne +
        lda funds
        cmp tt_cost-1,x
        bcs +
        lda #0
        rts
+       lda #1
        rts

try_build
        jsr can_build
        bcs _err
        jsr sel_affordable
        beq _err
        ldx #0                          ; a free defender
-       lda t_type,x
        beq _got
        inx
        cpx #MAX_TW
        bne -
_err    lda #SFX_ERROR
        jmp sfx_play
_got    lda sel_type
        sta t_type,x
        lda cur_c
        sta t_col,x
        asl a
        asl a
        adc #2
        sta t_cx,x
        lda cur_r
        sta t_row,x
        tay
        lda mul12,y
        adc #6
        sta t_cy,x
        lda #8
        sta t_cd,x
        lda #0
        sta t_dis,x
        stx t0
        jsr cursor_ptr                  ; 2 = blocked: $40 marks it
        and #2
        asl a
        asl a
        asl a
        asl a
        asl a
        ora #$80
        ora t0
        sta (ptr),y
        ldx sel_type                    ; paid for; its damage as points
        lda funds
        sec
        sbc tt_cost-1,x
        sta funds
        bcs +
        dec funds+1
+       lda tt_dmg-1,x
        jsr score_add_a
        jsr redraw_cursor_cell
        jsr all_damage
        lda #SFX_BUILD
        jsr sfx_play
        lda #HUDF_FUNDS|HUDF_INFO|HUDF_TOP
        jmp hud_set

try_sell
        jsr cursor_ptr
        bmi +
        rts
+       tax
        and #$1f
        sta t0
        lda #0                          ; the cell as it was
        cpx #$c0
        bcc +
        lda #2
+       sta (ptr),y
        ldy t0
        ldx t_type,y
        lda #0
        sta t_type,y
        lda funds                       ; half its price back, its points gone
        clc
        adc tt_sell-1,x
        sta funds
        bcc +
        inc funds+1
+       lda score
        sec
        sbc tt_dmg-1,x
        sta score
        lda score+1
        sbc #0
        sta score+1
        bcs +
        lda #0
        sta score
        sta score+1
+       jsr redraw_cursor_cell
        jsr all_damage
        lda #SFX_SELL
        jsr sfx_play
        lda #HUDF_FUNDS|HUDF_INFO|HUDF_TOP
        jmp hud_set

redraw_cursor_cell
        ldx cur_c
        ldy cur_r
        jmp redraw_tile

; N: the wave now, half the seconds left paid, all of them as points
call_wave_now
        lda wave_state
        beq +
        rts
+       lda cd_sec
        jsr score_add_a
        lda cd_sec
        lsr a
        clc
        adc funds
        sta funds
        bcc +
        inc funds+1
+       lda #HUDF_FUNDS|HUDF_TOP
        jsr hud_set
        jmp start_wave

; =============================================================================
; helpers
; =============================================================================
; A = points: added to the score (it stops at 65535)
score_add_a
        clc
        adc score
        sta score
        bcc +
        inc score+1
        bne +
        lda #$ff
        sta score
        sta score+1
+       rts

; A = vrouves earned, t0 = points
pay     clc
        adc funds
        sta funds
        bcc +
        inc funds+1
+       lda t0
        jmp score_add_a

; -> A random.  Preserves X, Y.
rand    lda seed
        asl a
        rol seed+1
        bcc +
        eor #$2d
+       sta seed
        eor seed+1
        rts

; A = flags: the HUD to draw again
hud_set ora hud_flags
        sta hud_flags
        rts

; A = effect.  Preserves X, Y.
sfx_play
        stx sfx_x
        sty sfx_y
        ldy sfx_request                 ; one asked for this frame already: the
        beq _take                       ; higher one stays
        tax
        lda sfx_prio-1,x
        cmp sfx_prio-1,y
        bcc _keep
        txa
_take   sta sfx_request
_keep   ldx sfx_x
        ldy sfx_y
        rts

sfx_x           .byte 0
sfx_y           .byte 0

mul12           .byte range(0, 14*12, 12)

; X = col, Y = row: the tile's cells drawn again
redraw_tile
        stx t6
        sty t7
        jsr shots_erase                 ; (no shot over it while it changes)
        ldx t6
        ldy t7
        jmp compose_tile

; =============================================================================
; waves
; =============================================================================
wave_update
        lda hp
        bne _alive
        lda #2
        sta game_over
        rts
_alive  lda wave_state
        bne _active
        lda cd_sub
        bne _sub
        lda cd_sec
        bne +
        jmp start_wave
+       dec cd_sec
        lda #25
        sta cd_sub
        lda #HUDF_STATUS
        jsr hud_set
_sub    dec cd_sub
        rts
_active jsr spawn_tick
        lda sp_left
        ora en_count
        beq +
        rts
+       lda wave_num                    ; wave cleared: 15 + 3 * wave
        asl a
        adc wave_num
        adc #15
        clc
        adc funds
        sta funds
        bcc +
        inc funds+1
+       lda #HUDF_FUNDS|HUDF_STATUS
        jsr hud_set
        lda wave_num
        cmp #NUM_WAVES
        bne _more
        lda funds                       ; stage won: the vrouves left are points
        clc
        adc score
        sta score
        lda funds+1
        adc score+1
        sta score+1
        bcc +
        lda #$ff
        sta score
        sta score+1
+       lda #HUDF_TOP
        jsr hud_set
        lda #1
        sta game_over
        rts
_more   lda #0
        sta wave_state
        lda #NEXT_COUNTDOWN
        sta cd_sec
        lda #25
        sta cd_sub
        lda #B_CLEAR
        ldx #B_NEXT
        jsr msg_show
        lda #SFX_SELL
        jmp sfx_play

start_wave
        lda ban_timer                   ; the announcement makes way
        beq +
        jsr banner_clear
+       lda wave_num
        cmp #NUM_WAVES
        bcc +
        rts
+       ldx stage                       ; the wave's groups: skip the waves before
        lda st_waves_lo,x
        sta sp_ptr
        lda st_waves_hi,x
        sta sp_ptr+1
        ldx wave_num
        beq _found
        ldy #0
-       lda (sp_ptr),y
        beq _endw
        lda sp_ptr
        clc
        adc #3
        sta sp_ptr
        bcc -
        inc sp_ptr+1
        bne -
_endw   inc sp_ptr
        bne +
        inc sp_ptr+1
+       dex
        bne -
_found  inc wave_num
        lda #1
        sta wave_state
        jsr load_group
        lda #10
        sta sp_timer
        lda wave_num
        cmp #NUM_WAVES
        bne _nf
        lda #B_FINAL
        ldx #$ff
        jsr msg_show
        lda #100
        sta msg_timer
        jmp +
_nf     jsr msg_clear
+       lda #SFX_WAVE
        jsr sfx_play
        lda #HUDF_WAVE|HUDF_STATUS
        jmp hud_set

load_group
        ldy #0
        lda (sp_ptr),y
        bne +
        sta sp_left
        rts
+       sta sp_type
        iny
        lda (sp_ptr),y
        sta sp_left
        iny
        lda (sp_ptr),y
        sta sp_iv
        sta sp_timer
        lda sp_ptr
        clc
        adc #3
        sta sp_ptr
        bcc +
        inc sp_ptr+1
+       rts

spawn_tick
        lda sp_left
        bne +
        rts
+       dec sp_timer
        beq +
        rts
+       lda sp_type
        jsr spawn_enemy
        bcs _ok
        lda #1
        sta sp_timer
        rts
_ok     lda sp_iv
        sta sp_timer
        dec sp_left
        bne +
        jmp load_group
+       rts

; =============================================================================
; invaders
; =============================================================================
; A = type -> C set if one came
spawn_enemy
        sta t0
        ldx #0
-       lda e_type,x
        beq _got
        inx
        cpx #MAX_EN
        bne -
        clc
        rts
_got    ldy t0
        tya
        sta e_type,x
        lda wave_num                    ; health: base + a wave's * (wave + toughness)
        ldy stage
        clc
        adc st_tough,y
        sta t1
        ldy t0
        lda et_hp-1,y
-       clc
        adc et_hpw-1,y
        bcc +
        lda #255
+       dec t1
        bne -
        sta e_hp,x
        lda et_spd-1,y
        sta e_spd,x
        lda et_arm-1,y
        sta e_arm,x
        lda #0
        sta e_acc,x
        sta e_prog_lo,x
        sta e_prog_hi,x
        sta e_slow,x
        sta e_seg,x
        jsr rand
        sta e_anim,x
        inc gen_ctr
        lda gen_ctr
        sta e_gen,x
        jsr enemy_path
        ldy #0
        lda (ptr2),y
        sta e_x,x
        iny
        lda (ptr2),y
        sta e_y,x
        iny
        lda (ptr2),y
        sta e_sub,x
        iny
        lda (ptr2),y
        sta e_rem,x
        inc en_count
        sec
        rts

; X = invader -> ptr2 = its path.  Preserves X, Y.
enemy_path
        lda e_type,x
        cmp #ET_DRONE
        beq +
        lda path_g
        sta ptr2
        lda path_g+1
        sta ptr2+1
        rts
+       lda path_a
        sta ptr2
        lda path_a+1
        sta ptr2+1
        rts

; X = invader -> ptr2 = its path, Y = the offset of its segment (dx, dy, n)
enemy_seg
        jsr enemy_path
        lda e_seg,x
        sta t7
        asl a
        adc t7
        adc #4
        tay
        rts

update_enemies
        ldx #0
-       lda e_type,x
        beq +
        stx ix
        jsr enemy_move
        ldx ix
+       inx
        cpx #MAX_EN
        bne -
        rts

enemy_move
        lda e_spd,x
        ldy e_slow,x
        beq +
        dec e_slow,x
        lsr a
+       clc
        adc e_acc,x
        tay
        and #15
        sta e_acc,x
        tya
        lsr a
        lsr a
        lsr a
        lsr a
        beq _anim
        sta t5
-       jsr enemy_step
        bcs _arrived
        dec t5
        bne -
_anim   inc e_anim,x
        lda e_type,x
        cmp #ET_TANK
        bne +
        lda e_anim,x
        and #7
        bne +
        jmp tank_crush
+       rts
_arrived
        ldy e_type,x
        lda #0
        sta e_type,x
        dec en_count
        lda et_dmg-1,y
        jmp base_hit

; one step along the path -> C set if the building was reached
enemy_step
        jsr enemy_seg
        lda (ptr2),y                    ; dx
        sta t4
        iny
        lda (ptr2),y                    ; dy
        clc
        adc e_y,x
        sta e_y,x
        inc e_sub,x
        lda e_sub,x
        cmp #3
        bcc +
        lda #0
        sta e_sub,x
        lda e_x,x
        clc
        adc t4
        sta e_x,x
+       inc e_prog_lo,x
        bne +
        inc e_prog_hi,x
+       dec e_rem,x
        beq +
        clc
        rts
+       inc e_seg,x
        jsr enemy_seg
        iny
        iny
        lda (ptr2),y
        bne +
        sec
        rts
+       sta e_rem,x
        clc
        rts

; A = damage to the building
base_hit
        sta t0
        lda hp
        sec
        sbc t0
        bcs +
        lda #0
+       sta hp
        lda #HUDF_HP
        jsr hud_set
        lda #SFX_HURT
        jsr sfx_play
        ; (on to update_sacks)

; a sack goes for every 20 health under 100
update_sacks
        lda sacks_gone
        cmp #NUM_SACKS
        bcc +
        rts
+       asl a                           ; 80 - 20 * sacks gone
        asl a
        sta t0
        asl a
        asl a
        adc t0
        sta t0
        lda #80
        sec
        sbc t0
        cmp hp
        bcs +
        rts
+       ldx stage                       ; its cell gets the tile without it
        lda st_sacks_lo,x
        sta src
        lda st_sacks_hi,x
        sta src+1
        lda sacks_gone
        asl a
        asl a
        tay
        lda (src),y
        sta t2                          ; col
        iny
        lda (src),y
        sta t3                          ; row
        iny
        iny
        lda (src),y
        pha
        ldx t2
        ldy t3
        jsr cell_ptr
        pla
        sta (ptr2),y
        inc sacks_gone
        ldx t2
        ldy t3
        jsr redraw_tile
        jmp update_sacks

; X = invader, A = damage, t2 bit 0 = through armour.  Preserves X.
damage_enemy
        sta t0
        lda t2
        lsr a
        bcs _na
        lda t0
        sec
        sbc e_arm,x
        beq +
        bcs ++
+       lda #1
+       sta t0
_na     lda e_hp,x
        sec
        sbc t0
        beq kill_enemy
        bcc kill_enemy
        sta e_hp,x
        rts

kill_enemy
        ldy e_type,x
        lda et_dmg-1,y                  ; points: the damage it would have done
        sta t0
        lda et_rew-1,y
        jsr pay
        ldy e_type,x
        lda #0
        sta e_type,x
        dec en_count
        lda #FX_POOF
        cpy #ET_TANK
        bne +
        lda #FX_BOOM
+       ldy e_x,x
        sty fx_px
        ldy e_y,x
        sty fx_py
        jsr spawn_fx
        lda #SFX_DIE
        jsr sfx_play
        lda #HUDF_FUNDS|HUDF_TOP
        jmp hud_set

; a tank dents the cauldrons next to it
tank_crush
        lda e_x,x
        clc
        adc #2
        lsr a
        lsr a
        and #63
        sta cr_c
        lda e_y,x
        clc
        adc #6
        ldy #0
-       cmp #12
        bcc +
        sbc #12
        iny
        bne -
+       sty cr_r
        dec cr_c
        jsr crush_at
        inc cr_c
        inc cr_c
        jsr crush_at
        dec cr_c
        dec cr_r
        jsr crush_at
        inc cr_r
        inc cr_r
        jsr crush_at
        ldx ix
        rts

crush_at
        ldx cr_c
        cpx #NCOL
        bcs _o
        ldy cr_r
        cpy #NROW
        bcs _o
        jsr cell_ptr
        lda (ptr),y
        bpl _o
        and #$1f
        tay
        lda t_type,y
        cmp #TT_CAULDRON
        bne _o
        lda t_dis,y
        bne _o
        lda #125
        sta t_dis,y
        ldx cr_c
        ldy cr_r
        jsr redraw_tile
        lda #SFX_CRUSH
        jsr sfx_play
_o      rts

cr_c            .byte 0
cr_r            .byte 0

; =============================================================================
; defenders
; =============================================================================
update_towers
        ldy #0
-       lda t_type,y
        beq +
        sty iy
        jsr tower_think
        ldy iy
+       iny
        cpy #MAX_TW
        bne -
        rts

tower_think
        lda t_dis,y
        beq _en
        sec
        sbc #1
        sta t_dis,y
        bne +
        ldx t_col,y                     ; the cauldron mended
        lda t_row,y
        tay
        jmp redraw_tile
+       rts
_en     lda t_cd,y
        beq _rdy
        sec
        sbc #1
        sta t_cd,y
        rts
_rdy    lda tr_budget                   ; only a few look for a target a tick
        bne +
        rts
+       dec tr_budget
        ldx t_type,y
        lda tt_range-1,x
        sta tr_range
        tax
        lda sq_lo,x
        sta tr_range2
        lda sq_hi,x
        sta tr_range2+1
        ldx t_type,y
        lda tt_cd-1,x
        sta tr_cd
        lda tt_air-1,x
        sta tr_flags
        lda tt_proj-1,x
        sta tr_proj
        lda tt_sfx-1,x
        sta tr_sfx
        lda t_dmg,y                     ; the damage, with the neighbour bonus
        sta tr_dmg
        jsr find_target
        bcs _fire
        ldy iy
        lda #4                          ; nobody in reach: again later
        sta t_cd,y
        rts
_fire   ldy iy
        lda tr_cd
        sta t_cd,y
        stx ix
        lda tr_sfx
        jsr sfx_play
        ldx ix
        ldy iy
        lda t_type,y
        cmp #TT_YIAYIA
        bne +
        jmp fire_yiayia
+       cmp #TT_CAULDRON
        bne +
        jmp fire_cauldron
+       lda t_type,y                    ; the bride: criticals
        cmp #TT_BRIDE
        bne _nc
        jsr rand
        cmp #64
        bcs _nc
        lda tr_dmg                      ; 1 in 4: three times the damage
        asl a
        adc tr_dmg
        sta tr_dmg
        lda #1
        bne +                           ; (always)
_nc     lda #0
+       sta sp_pflag
        lda tr_proj
        jmp spawn_proj

; every defender's damage again (one was built or sold: its neighbours change)
all_damage
        ldy #MAX_TW-1
-       lda t_type,y
        beq +
        sty iy
        jsr syn_dmg
        ldy iy
        lda tr_dmg
        sta t_dmg,y
+       dey
        bpl -
        rts

; Y = defender -> tr_dmg: its damage, more or less with a partner next door
syn_dmg
        ldx t_type,y
        lda tt_dmg-1,x
        sta tr_dmg
        sty t6
        lda t_row,y
        pha
        ldx t_col,y
        lda t_type,y
        sta t7
        pla
        tay
        lda t7
        jsr syn_find
        ldy t6
        bcc _x
        lda syn_factor-1,x              ; damage * factor / 16, rounded
        sta t1
        lda #8
        sta t2
        lda #0
        sta t3
-       lda t2
        clc
        adc tr_dmg
        sta t2
        bcc +
        inc t3
+       dec t1
        bne -
        lda t3                          ; / 16
        asl t2
        rol a
        asl t2
        rol a
        asl t2
        rol a
        asl t2
        rol a
        sta tr_dmg
_x      rts

; A = type, X = col, Y = row -> C set and X = type when a partner is next
; door (left, right, above, below)
syn_find
        sta t3
        stx t4
        sty t5
        tax
        lda syn_partner-1,x
        bne +
        clc
        rts
+       sta t1
        ldy #MAX_TW-1
_l      lda t_type,y
        cmp t1
        bne _n
        lda t_col,y
        sec
        sbc t4
        beq _col                        ; the same column: rows one apart
        clc
        adc #1                          ; else columns one apart...
        and #$fd
        bne _n
        lda t_row,y                     ; ...on the same row
        cmp t5
        beq _hit
        bne _n
_col    lda t_row,y
        sec
        sbc t5
        clc
        adc #1
        and #$fd
        beq _hit
_n      dey
        bpl _l
        clc
        rts
_hit    ldx t3
        sec
        rts

; Y = defender -> C set and X = the invader furthest along within reach
find_target
        lda #0
        sta best_prog
        sta best_prog+1
        ldx #0
_l      lda e_type,x
        beq _n
        cmp #ET_DRONE
        bne +
        lda tr_flags
        beq _n
+       jsr in_range
        bcc _n
        lda e_prog_lo,x                 ; prog + 1 > best?
        clc
        adc #1
        sta t0
        lda e_prog_hi,x
        adc #0
        sta t1
        lda best_prog
        cmp t0
        lda best_prog+1
        sbc t1
        bcs _n
        lda t0
        sta best_prog
        lda t1
        sta best_prog+1
        stx best_ix
_n      inx
        cpx #MAX_EN
        bne _l
        lda best_prog
        ora best_prog+1
        bne +
        clc
        rts
+       ldx best_ix
        sec
        rts

; X = invader, Y = defender -> C set if within tr_range.  Preserves X, Y.
in_range
        lda e_x,x
        clc
        adc #2
        sec
        sbc t_cx,y
        bcs +
        eor #$ff
        adc #1
+       sta t0                          ; |dx| * 3 (a unit is two pixels)
        asl a
        bcs _no
        adc t0
        bcs _no
        cmp tr_range
        beq +
        bcs _no
+       sta t0
        lda e_y,x
        clc
        adc #6
        sec
        sbc t_cy,y
        bcs +
        eor #$ff
        adc #1
+       cmp tr_range
        beq +
        bcs _no
+       sty t2
        tay
        lda sq_lo,y
        sta t1
        lda sq_hi,y
        sta t3
        ldy t0
        lda sq_lo,y
        clc
        adc t1
        sta t1
        lda sq_hi,y
        adc t3
        sta t3
        ldy t2
        lda tr_range2                   ; range^2 >= dx^2 + dy^2 ?
        cmp t1
        lda tr_range2+1
        sbc t3
        rts                             ; (C set: yes)
_no     clc
        rts

; slows every walker in reach, whacks the target (X)
fire_yiayia
        stx t5
        ldx #MAX_EN-1
_l      lda e_type,x
        beq _n
        cmp #ET_DRONE
        beq _n
        jsr in_range
        bcc _n
        lda #40
        sta e_slow,x
_n      dex
        bpl _l
        ldx t5
        lda e_x,x
        sta fx_px
        lda e_y,x
        sta fx_py
        lda #FX_BASH
        jsr spawn_fx
        lda #0
        sta t2
        lda tr_dmg
        jmp damage_enemy

; a toxic cloud: hurts (through armour) and slows every walker in reach
fire_cauldron
        lda #2                          ; at most two clouds a throw
        sta t5
        ldx #MAX_EN-1
_l      lda e_type,x
        beq _n
        cmp #ET_DRONE
        beq _n
        ldy iy
        jsr in_range
        bcc _n
        lda #30
        sta e_slow,x
        lda t5
        beq +
        dec t5
        lda e_x,x
        sta fx_px
        lda e_y,x
        sta fx_py
        lda #FX_PUFF
        jsr spawn_fx
+       lda #1
        sta t2
        lda tr_dmg
        jsr damage_enemy
_n      dex
        bpl _l
        rts

; =============================================================================
; shots
; =============================================================================
; A = type, tr_dmg = damage, sp_pflag = flags, X = target, Y = defender
spawn_proj
        sta sp_ptype
        sty t6
        ldy #0
-       lda p_type,y
        beq _got
        iny
        cpy #MAX_PR
        bne -
        rts
_got    lda sp_ptype
        sta p_type,y
        sty t7
        ldy t6
        lda t_cx,y
        asl a
        pha
        lda t_cy,y
        sec
        sbc #4
        ldy t7
        sta p_y,y
        pla
        sta p_x,y
        txa
        sta p_tgt,y
        lda tr_dmg
        sta p_dmg,y
        lda sp_pflag
        sta p_flag,y
        lda e_x,x
        clc
        adc #2
        asl a
        sta p_tx,y
        lda e_y,x
        adc #6
        sta p_ty,y
        lda e_gen,x
        sta p_gen,y
        rts

update_projs
        ldy #0
-       lda p_type,y
        beq +
        sty iy
        jsr proj_step
        ldy iy
+       iny
        cpy #MAX_PR
        bne -
        rts

proj_step
        ldx p_tgt,y
        lda e_type,x
        beq _lost
        lda e_gen,x
        cmp p_gen,y
        bne _lost
        lda e_x,x
        clc
        adc #2
        asl a
        sta p_tx,y
        lda e_y,x
        adc #6
        sta p_ty,y
        jmp _mv
_lost   lda p_flag,y
        ora #$80
        sta p_flag,y
_mv     ldx p_type,y
        lda pr_sx-1,x
        sta t0
        lda pr_sy-1,x
        sta t1
        lda #0
        sta t2                          ; bit 0 there across, bit 1 down
        lda p_tx,y
        sec
        sbc p_x,y
        bcc _xl
        cmp t0
        bcs +
        sta t0
        inc t2
+       lda p_x,y
        clc
        adc t0
        sta p_x,y
        jmp _y
_xl     eor #$ff
        adc #1
        cmp t0
        bcs +
        sta t0
        inc t2
+       lda p_x,y
        sec
        sbc t0
        sta p_x,y
_y      lda p_ty,y
        sec
        sbc p_y,y
        bcc _yu
        cmp t1
        bcs +
        sta t1
        lda t2
        ora #2
        sta t2
+       lda p_y,y
        clc
        adc t1
        sta p_y,y
        jmp _chk
_yu     eor #$ff
        adc #1
        cmp t1
        bcs +
        sta t1
        lda t2
        ora #2
        sta t2
+       lda p_y,y
        sec
        sbc t1
        sta p_y,y
_chk    lda t2
        cmp #3
        beq _impact
        rts
_impact lda p_type,y
        sta t3
        lda #0
        sta p_type,y
        lda t3
        cmp #PT_DAKOS
        beq _splash
        lda p_x,y
        lsr a
        sec
        sbc #1
        sta fx_px
        lda p_y,y
        sec
        sbc #2
        sta fx_py
        lda #FX_SPARK
        ldx t3
        cpx #PT_LASER
        bne +
        lda #FX_ZAP
+       jsr spawn_fx
        ldy iy
        lda p_flag,y
        bmi _r
        ldx p_tgt,y
        lda t3
        cmp #PT_LASER                   ; the laser melts armour
        bne +
        lda e_arm,x
        beq +
        dec e_arm,x
+       lda #0
        sta t2
        lda p_dmg,y
        jmp damage_enemy
_r      rts
_splash lda p_x,y
        lsr a
        sta t4                          ; t4 = x in two pixel units
        sec
        sbc #2
        sta fx_px
        lda p_y,y
        sec
        sbc #6
        sta fx_py
        lda #FX_BASH
        jsr spawn_fx
        ldy iy
        ldx #MAX_EN-1
_sl     lda e_type,x
        beq _sn
        lda e_x,x
        clc
        adc #2
        sec
        sbc t4
        bcs +
        eor #$ff
        adc #1
+       cmp #5
        bcs _sn
        lda e_y,x
        clc
        adc #6
        sec
        sbc p_y,y
        bcs +
        eor #$ff
        adc #1
+       cmp #13
        bcs _sn
        lda #0
        sta t2
        lda p_dmg,y
        jsr damage_enemy
        ldy iy
_sn     dex
        bpl _sl
        rts

; =============================================================================
; effects
; =============================================================================
; A = type at fx_px, fx_py (kept on the playfield).  Preserves X, Y.
spawn_fx
        stx fx_sx
        sty fx_sy
        sta t7
        ldx #MAX_FX-1
-       lda f_type,x
        beq _got
        dex
        bpl -
        bmi _out                        ; (always)
_got    lda t7
        sta f_type,x
        tay
        lda fx_life-1,y
        sta f_t,x
        lda fx_px
        cmp #128
        bcc +
        lda #0
+       cmp #77
        bcc +
        lda #76
+       sta f_x,x
        lda fx_py
        cmp #200
        bcc +
        lda #0
+       cmp #157
        bcc +
        lda #156
+       sta f_y,x
_out    ldx fx_sx
        ldy fx_sy
        rts

fx_px           .byte 0
fx_py           .byte 0
fx_sx           .byte 0
fx_sy           .byte 0

update_fx
        ldx #MAX_FX-1
-       lda f_type,x
        beq +
        dec f_t,x
        bne +
        lda #0
        sta f_type,x
+       dex
        bpl -
        rts

; =============================================================================
; the picture: the flag waves, the sprites
; =============================================================================
flag_tick
        lda frame
        and #16
        beq +
        lda #1
+       cmp flag_frame
        beq +
        sta flag_frame
        jmp compose_flag
+       rts

; the sprite objects of this frame: the cursor, the invaders (from a
; different one each frame), the effects
build_sprites
        jsr obj_clear
        lda game_over                   ; the cursor, not over the end banner
        bne _en
        jsr cursor_ptr
        bmi _ok
        jsr can_build
        bcs _bad
        jsr sel_affordable
        beq _bad
_ok     ldy #SPR_CURSOR_OK
        lda frame
        and #8
        beq +
        ldy #SPR_CURSOR_OKB
        bne +                           ; (always)
_bad    ldy #SPR_CURSOR_BAD
+       lda sprite_colour,y
        sta t0
        ldx cur_r
        lda mul12,x
        clc
        adc #SPR_Y0
        pha
        lda cur_c
        asl a
        asl a
        tax
        pla
        jsr obj_add
_en     lda ob_rot
        clc
        adc #5
        and #15
        sta ob_rot
        sta t5
        lda #MAX_EN
        sta t6
-       ldx t5
        lda e_type,x
        beq _ne
        jsr enemy_sprite_idx
        tay
        lda enemy_frames,y
        tay
        lda sprite_colour,y
        sta t0
        ldx t5
        lda e_y,x
        clc
        adc #SPR_Y0
        pha
        lda e_x,x
        tax
        pla
        jsr obj_add
_ne     lda t5
        clc
        adc #1
        and #15
        sta t5
        dec t6
        bne -
        ldx #MAX_FX-1
-       lda f_type,x
        beq _nf
        stx t5
        tay
        lda f_t,x
        and #4
        bne +
        lda fx_a-1,y
        jmp ++
+       lda fx_b-1,y
+       tay
        lda sprite_colour,y
        sta t0
        lda f_y,x
        clc
        adc #SPR_Y0
        pha
        lda f_x,x
        tax
        pla
        jsr obj_add
        ldx t5
_nf     dex
        bpl -
        jmp mux_build

; the list built and taken: wait until the IRQ has it
mux_build_wait
        jsr mux_build
-       lda dl_ready
        bne -
        rts

; X = invader -> A = its frame: (type, direction, step)
enemy_sprite_idx
        jsr enemy_seg
        lda (ptr2),y                    ; dx: 0 down, <0 left, >0 right
        beq +
        bmi _l
        lda #2
        bne +
_l      lda #1
+       sta t7
        lda e_type,x
        sec
        sbc #1
        sta t4
        asl a
        adc t4
        adc t7
        asl a
        sta t7
        lda e_anim,x
        lsr a
        lsr a
        and #1
        ora t7
        rts

; =============================================================================
; the banner (playfield rows 9-11) and the top bar's messages
; =============================================================================
; A = first text, X = second ($ff: none)
banner_show
        sta ban_id1
        stx ban_id2
        lda #1
        sta ban_on
        lda #0
        sta ban_timer
        ; (on to banner_draw)

banner_draw
        jsr shots_erase
        lda #PF_ROW+BAN_ROW
        sta t0
        lda #3
        sta t1
        lda #0
        sta t3
        lda #40
        sta t4
        lda #COL_BLUE
        sta t2
        jsr fill_cells
        ldx #COL_YELLOW
        ldy #COL_BLUE
        jsr set_colors
        jsr text_normal
        lda ban_id2
        cmp #$ff
        bne +
        lda ban_id1                     ; one line: in the middle
        ldy #PF_ROW+BAN_ROW+1
        jsr print_id_centered
        jmp _frame
+       lda ban_id1
        ldy #PF_ROW+BAN_ROW
        jsr print_id_centered
        ldx #COL_WHITE
        ldy #COL_BLUE
        jsr set_colors
        lda ban_id2
        ldy #PF_ROW+BAN_ROW+2
        jsr print_id_centered
_frame  ldx #PF_ROW+BAN_ROW             ; a yellow frame: lines at the top and
        ldy #0                          ; the bottom, the sides
        lda #COL_YELLOW
        jsr hline
        ldx #PF_ROW+BAN_ROW+2
        ldy #7
        lda #COL_YELLOW
        jsr hline
        ldx #PF_ROW+BAN_ROW
_side   stx t5
        jsr cell_addr_x0
        ldy #7
-       lda (bmp),y                     ; column 0, pixel 0
        ora #$c0
        sta (bmp),y
        dey
        bpl -
        lda bmp                         ; column 39, pixel 3
        clc
        adc #<(39*8)
        sta bmp
        lda bmp+1
        adc #>(39*8)
        sta bmp+1
        ldy #7
-       lda (bmp),y
        ora #$03
        sta (bmp),y
        dey
        bpl -
        ldy #0
        lda #COL_YELLOW
        sta (colp),y
        ldy #39
        sta (colp),y
        ldx t5
        inx
        cpx #PF_ROW+BAN_ROW+3
        bne _side
        rts

banner_clear
        lda ban_on
        bne +
        rts
+       lda #0
        sta ban_on
        sta ban_timer
        jsr shots_erase
        ldy #BAN_ROW
_r      ldx #0
-       stx t6
        sty t7
        jsr compose_cell
        ldx t6
        ldy t7
        inx
        cpx #40
        bne -
        iny
        cpy #BAN_ROW+3
        bne _r
        rts

banner_tick                             ; the announcement goes after a while
        lda ban_timer
        beq +
        dec ban_timer
        bne +
        jsr banner_clear
+       lda msg_timer                   ; timed messages in the top bar
        bne +
        rts
+       dec msg_timer
        beq msg_clear
        rts

msg_clear
        lda msg_on
        bne +
        rts
+       lda #0
        sta msg_on
        lda #HUDF_TOP
        jmp hud_set

; A = first text, X = second ($ff: none): in the top bar
msg_show
        sta msg_id1
        stx msg_id2
        lda #1
        sta msg_on
        lda #0
        sta msg_timer
        lda #HUDF_TOP
        jmp hud_set
