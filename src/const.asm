; =============================
;   Tweak to change grid size
; =============================
.equ COLUMNS, 16
.equ ROWS, 16

.if COLUMNS < 3
.abort "COLUMNS variable must be >= 3"
.elseif COLUMNS > 32
.abort "COLUMNS variable must be <= 32"
.elseif ROWS < 3
.abort "ROWS variable must be >= 3"
.elseif ROWS > 26
.abort "COLUMNS variable must be <= 26"
.endif

.equ MINE_COUNT, 40

.if MINE_COUNT >= (ROWS * COLUMNS)
.abort "Cannot have more mines than cells on the board"
.endif

.equ TOTAL_ROWS, ROWS + 2
.equ TOTAL_COLS, COLUMNS + 2
.equ INNER_GRID_START, grid + TOTAL_COLS + 1

.equ GRID_START_X, ((32 - COLUMNS) / 2)
.equ GRID_START_Y, ((30 - ROWS) / 2)
.equ GRID_START_POS, (GRID_START_Y * 32) + GRID_START_X

.equ TILE_BLANK, 0
.equ TILE_COVERED, 1
.equ TILE_CURSOR, 2
.equ TILE_REVEALED, 3
.equ TILE_FLAG, 4
.equ TILE_MINE, 5
.equ TILE_MINE_BOOM, 6
.equ TILE_DIGIT_0, 7
.equ TILE_COLON, 17
.equ TILE_QUESTION, 18

.equ CELL_IS_BORDER, 0xFF ; ignore everything else, this cell is a border

.equ CELL_REVEALED, 0x00 ; can only be one of the following, if flagged/question marked is also covered
.equ CELL_COVERED, 0x01
.equ CELL_FLAGGED, 0x02
.equ CELL_QUESTION, 0x03
.equ CELL_STATE_MASK, 0b11

.equ CELL_HAS_MINE, 0x04
.equ CELL_NEIGHBOR_MASK, 0xF0

.equ GAME_PLAYIND, 0
.equ GAME_LOST, 1
.equ GAME_WON, 2
