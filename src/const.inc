; =============================================================================
; const.inc - memory map and the game's constants
; =============================================================================

; --- memory (VIC bank 3: $c000-$ffff) -----------------------------------------
SCREEN          = $c000                 ; screen RAM: the cells' colours 1 and 2
WORK            = $c400                 ; workspace (vars.inc), up to $cfff
SPRITES         = $d000                 ; sprite blocks, in the RAM under the I/O
BITMAP          = $e000                 ; the multicolour bitmap, under the KERNAL
SPR_PTRS        = SCREEN + $3f8
SPR_PTR0        = (SPRITES - $c000) / 64        ; the pointer of sprite block 0
VIC_MEM_GAME    = $08                   ; screen $c000, bitmap $e000

FRAME_LINE      = 251                   ; the frame's interrupt, in the bottom border

; --- the screen -----------------------------------------------------------------
PF_ROW          = 2                     ; the playfield: character rows 2-22
PF_ROWS         = 21                    ; (168 lines: 14 rows of 12-line tiles)
PF_Y            = 16                    ; its first line
NCOL            = 20                    ; tiles across
NROW            = 14                    ; tiles down
NCELLS          = NCOL*NROW
HUD_ROW1        = 23
HUD_ROW2        = 24
BAN_ROW         = 9                     ; the banner: playfield rows 9-11 (tile rows 6-7)
SPR_Y0          = 50 + PF_Y             ; a sprite's Y register for playfield line 0
SPR_X0          = 24                    ; ... X for pixel 0

; --- keys: row * 8 + column of the keyboard matrix ------------------------------
K_DEL           = 0
K_RETURN        = 1
K_F1            = 4
K_3             = 8
K_A             = 10
K_4             = 11
K_S             = 13
K_5             = 16
K_D             = 18
K_6             = 19
K_H             = 29
K_M             = 36
K_O             = 38
K_N             = 39
K_P             = 41
K_L             = 42
K_1             = 56
K_ARROW         = 57                    ; <- (left of 1)
K_2             = 59
K_SPACE         = 60
K_Q             = 62
K_STOP          = 63
J_UP            = 64                    ; the joysticks (ports 2 and 1)
J_DOWN          = 65
J_LEFT          = 66
J_RIGHT         = 67
J_FIRE          = 68
C_UP            = 72                    ; the cursor keys (up and left with a shift)
C_DOWN          = 73
C_LEFT          = 74
C_RIGHT         = 75
KEY_ROWS        = 10

; --- colours of the texts (C64) ---------------------------------------------------
COL_BLACK       = 0
COL_WHITE       = 1
COL_RED         = 2
COL_GREEN       = 5
COL_BLUE        = 6
COL_YELLOW      = 7
COL_ORANGE      = 8
COL_GREY        = 12
COL_LGREEN      = 13
COL_LBLUE       = 14

; --- the game -------------------------------------------------------------------
MAX_EN          = 16
MAX_TW          = 32
MAX_PR          = 20
MAX_FX          = 8
MAX_OBJ         = 32                    ; hardware sprite objects a frame
EMASK           = $0400                 ; the invaders' masks (shots.asm, made at start)
SWAPTAB         = $0700                 ; a byte's two halves swapped
SYN_MAX         = 3                     ; defenders with a neighbour bonus, at most
FC_MAX          = 6                     ; the flag's cells (3 x 2 at most)
PASS_FRAMES     = 4                     ; a pass of the game's loop: 12.5 a second

ET_DRONE        = 1
ET_GUARD        = 2
ET_TANK         = 3

TT_CRETAN       = 1
TT_YIAYIA       = 2
TT_BRIDE        = 3
TT_PSSSST       = 4
TT_CAULDRON     = 5
TT_BAKER        = 6

PT_BULLET       = 1
PT_PISTOL       = 2
PT_LASER        = 3
PT_DAKOS        = 4

FX_SPARK        = 1
FX_PUFF         = 2
FX_BASH         = 3
FX_POOF         = 4
FX_BOOM         = 5
FX_ZAP          = 6

TARGET_BUDGET   = 4
REP_FIRST       = 4                     ; the cursor's repeat, in passes of the loop
REP_NEXT        = 1

HUDF_WAVE       = 1
HUDF_INFO       = 2
HUDF_STATUS     = 4
HUDF_FUNDS      = 8
HUDF_HP         = 16
HUDF_TOP        = 32
HUDF_SCORE      = 64                    ; the score alone (the top bar takes long)

FIRST_COUNTDOWN = 45
NEXT_COUNTDOWN  = 15
