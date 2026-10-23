; =============================================================================
; vars.inc - the variables: zero page ($02-$8f: the KERNAL's own, from $90,
; stays as it was, for the disk) and the workspace at WORK ($c400-$cfff).
; Arrays are kept a field per table, indexed by X or Y.
; =============================================================================

        .virtual $02
frame           .byte ?                 ; +1 a frame (IRQ)
frame_hi        .byte ?
frame_seen      .byte ?                 ; the last frame the main loop saw
pass_frame      .byte ?                 ; the frame the last pass started in
ptr             .word ?                 ; general pointers
ptr2            .word ?
src             .word ?
dst             .word ?
bmp             .word ?                 ; a cell: bitmap, screen RAM, colour RAM
scrp            .word ?
colp            .word ?
tptr            .word ?                 ; compose.asm: the tile, the overlay
optr            .word ?
t0              .byte ?                 ; scratch
t1              .byte ?
t2              .byte ?
t3              .byte ?
t4              .byte ?
t5              .byte ?
t6              .byte ?
t7              .byte ?
snd_ptr         .word ?                 ; sound.asm (IRQ only)
ord_ptr         .word ?
irq_a           .byte ?                 ; the IRQ's own scratch
irq_x           .byte ?
irq_y           .byte ?
txt_col         .byte ?                 ; text: the next character,
txt_row         .byte ?
txt_col0        .byte ?                 ; where a new line starts,
txt_fg          .byte ?                 ; the colours,
txt_bg          .byte ?
txt_big         .byte ?                 ; twice the size
pn_zero         .byte ?                 ; print_num: leading zeros
num             .word ?
seed            .word ?                 ; the random numbers
mus_on          .byte ?
snd_want        .byte ?                 ; the tune the screen wants
sfx_request     .byte ?                 ; an effect to play (SFX_*)
lang            .byte ?                 ; 0 English, 1 Greek
stage           .byte ?
difficulty      .byte ?                 ; 0 medium, 1 hard, 2 hardest, 3 easy
score           .word ?                 ; this game's points
lives           .byte ?
score_chk       .word ?                 ; the score when this stage began
path_g          .word ?                 ; the stage's paths
path_a          .word ?
ix              .byte ?                 ; the enemy, tower, shot being worked on
iy              .byte ?
dl_ready        .byte ?                 ; a new sprite list for the IRQ
dl_show         .byte ?                 ; the list the IRQ shows: 0 or MAX_OBJ
mux_pos         .byte ?                 ; its next entry (IRQ)
mux_end         .byte ?
msb_shadow      .byte ?
test_keys       .byte ?                 ; tests: $ff = none
sp_ptr          .word ?                 ; the spawning: the next group
svp             .word ?                 ; shots.asm: the next free record of save_buf
dd_mp           .word ?                 ; shots.asm: an invader's masks,
dd_d            .fill 3                 ; a line's dark and bright pixels,
dd_b            .fill 3
dd_pd           .fill 3                 ; the cells' dark and bright patterns
dd_pb           .fill 3
        .endv

        .virtual WORK
; the stage, as it is played: tiles (local index), cell types / defenders
tmap            .fill NCELLS
cmap            .fill NCELLS            ; 0 grass, 1 road, 2 blocked, 3 building,
                                        ; $80+i defender i ($40: on a blocked cell)
tad_lo          .fill 96                ; the local tiles' addresses
tad_hi          .fill 96

; enemies
e_type          .fill MAX_EN
e_hp            .fill MAX_EN
e_arm           .fill MAX_EN
e_spd           .fill MAX_EN            ; path steps a tick * 16
e_acc           .fill MAX_EN
e_prog_lo       .fill MAX_EN            ; steps walked (the "first" one is shot at)
e_prog_hi       .fill MAX_EN
e_x             .fill MAX_EN            ; two pixel units
e_y             .fill MAX_EN            ; lines
e_slow          .fill MAX_EN
e_anim          .fill MAX_EN
e_gen           .fill MAX_EN
e_seg           .fill MAX_EN
e_rem           .fill MAX_EN
e_sub           .fill MAX_EN
; defenders
t_type          .fill MAX_TW
t_col           .fill MAX_TW
t_row           .fill MAX_TW
t_cd            .fill MAX_TW
t_cx            .fill MAX_TW
t_cy            .fill MAX_TW
t_dis           .fill MAX_TW
t_dmg           .fill MAX_TW            ; its damage, with the neighbour bonus
; shots
p_type          .fill MAX_PR
p_x             .fill MAX_PR            ; pixels
p_y             .fill MAX_PR
p_tgt           .fill MAX_PR
p_dmg           .fill MAX_PR
p_flag          .fill MAX_PR            ; bit 0 critical, bit 7 target lost
p_tx            .fill MAX_PR
p_ty            .fill MAX_PR
p_gen           .fill MAX_PR
; effects
f_type          .fill MAX_FX
f_x             .fill MAX_FX
f_y             .fill MAX_FX
f_t             .fill MAX_FX
ENT_END
; sprite objects (mux.asm), then the lists for the IRQ, two of them
ob_y            .fill MAX_OBJ
ob_x            .fill MAX_OBJ
ob_xh           .fill MAX_OBJ
ob_ptr          .fill MAX_OBJ
ob_col          .fill MAX_OBJ
ob_ord          .fill MAX_OBJ
ob_px           .fill MAX_OBJ           ; x (two pixel units), playfield line,
ob_line         .fill MAX_OBJ           ; sprite: for drawing it into the bitmap
ob_spr          .fill MAX_OBJ
ob_drop         .fill MAX_OBJ           ; no sprite for it this frame (mux_build)
ob_n            .byte ?
dl_line         .fill 2*MAX_OBJ
dl_spr          .fill 2*MAX_OBJ         ; the sprite * 2
dl_x            .fill 2*MAX_OBJ
dl_y            .fill 2*MAX_OBJ
dl_ptr          .fill 2*MAX_OBJ
dl_col          .fill 2*MAX_OBJ
dl_msb          .fill 2*MAX_OBJ         ; bit 0: X bit 8
dl_n            .fill 2                 ; entries, per list
fs_en           .fill 2                 ; the first use of each sprite, per list
fs_msb          .fill 2
fs_x            .fill 16
fs_y            .fill 16
fs_ptr          .fill 16
fs_col          .fill 16
mx_free         .fill 8                 ; mux_build: where each sprite is free
; compose.asm
pix             .fill 32
cnt             .fill 16
mapc            .fill 16
; the keys (input.asm): now, and the frame before
keys            .fill KEY_ROWS
kold            .fill KEY_ROWS
; the game's variables, cleared by game_init
GV_START
funds           .word ?
hp              .byte ?
wave_num        .byte ?
wave_state      .byte ?                 ; 0 counting down, 1 a wave on
cd_sec          .byte ?
cd_sub          .byte ?
sp_left         .byte ?                 ; how many still to come of this one,
sp_timer        .byte ?
sp_type         .byte ?
sp_iv           .byte ?
en_count        .byte ?
gen_ctr         .byte ?
game_over       .byte ?                 ; 1 won, 2 lost
quit            .byte ?
paused          .byte ?
cur_c           .byte ?
cur_r           .byte ?
sel_type        .byte ?
rep_t           .byte ?
hud_flags       .byte ?
hud_aff         .byte ?
ban_on          .byte ?
ban_id1         .byte ?
ban_id2         .byte ?
ban_timer       .byte ?
msg_on          .byte ?
msg_id1         .byte ?
msg_id2         .byte ?
msg_timer       .byte ?
sacks_gone      .byte ?
tmp_cost        .byte ?
tr_range        .byte ?
tr_range2       .word ?
tr_cd           .byte ?
tr_dmg          .byte ?
tr_flags        .byte ?
tr_proj         .byte ?
tr_sfx          .byte ?
tr_budget       .byte ?
best_prog       .word ?
best_ix         .byte ?
sp_ptype        .byte ?
sp_pdmg         .byte ?
sp_pflag        .byte ?
end_wait        .byte ?
ticks_due       .byte ?
frame_acc       .byte ?
flag_frame      .byte ?
unlock          .byte ?                 ; the stage's defenders, a bit per type
GV_END
SSTATE                                  ; sound.asm's state
        .fill 140
WORK_END
        .endv
        .cerror WORK_END > SPRITES, "the workspace runs into the sprites"
