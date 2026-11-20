.include "const.asm"
.include "../include/defs.inc"
.include "../include/my_macros.inc"

.header
    .ascii "BHM"
    .byte  1
    .ascii "WINMINE "
    .space 20, 0x00

.wram
; Holds grid graphics (covered and revealed cells) as well as the cursor
variables_start:
board_buffer:
    .space 2048

; Holds overlay graphics like flags, question marks and mines
overlays_buffer:
    .space 2048

movement_input_delay_frames:
    .space 1

command_input_delay_frames:
    .space 1

selected_cell:
    .space 2

last_selected_cell:
    .space 2

selected_cell_vram_offset:
    .space 2

last_cell_vram_offset:
    .space 2

xorshift_state:
    .space 2

grid:
    .space TOTAL_ROWS * TOTAL_COLS

game_state:
    .space 1

frames_elapsed:
    .space 1

seconds_elapsed:
    .space 2

flood_queue:
    .space (TOTAL_ROWS * TOTAL_COLS) * 2

queue_head:
    .space 2

queue_tail:
    .space 2

mines_placed:
    .space 1

cells_remaining:
    .space 2

time_digits:
    .space 3
variables_end:
    .equ VARIABLES_SIZE, variables_end - variables_start

.rom

_start:
    sei
	jsr setup_ivt

    xor a, a
    ld b, VARIABLES_SIZE
    bt bl, 1
    jnz .2
    st al, [b-]
    .2:
        st a, [b]
        djnc b, .2

    jsr init_grid

    ld al, TOTAL_COLS + 1
    st al, [selected_cell]
    st al, [last_selected_cell]

	ld   al, MMIO_PAGE
	mtdp al

    ld b, MASVOL
    ld al, [b]
    lsr al, 3
    st al, [b+]
    ld al, [b]
    lsr al, 3
    st al, [b]

    ld al, 6
	st al, [BACKDROP]

	ld al, 0b100 ; 4bpp, enabled
	st al, [BG1CTRL]
	st al, [BG2CTRL]
    or al, 1
	st al, [BG3CTRL]
	st al, [BG4CTRL]

	ld a, TILESET_VRAM_START
	st a, [BG1GFXSRC]
	st a, [BG2GFXSRC]
	st a, [BG3GFXSRC]
	st a, [BG4GFXSRC]
	st a, [OAMGFXSRC]

    ld a, 2048
    st a, [BG2ESRC]
    add a, 2048
    st a, [BG3ESRC]
    add a, 2048
    st a, [BG4ESRC]

	ld al, 0b111
	st al, [PPUCTRL]

	vdma_vram tileset_start, (TILESET_VRAM_START + 32), TILESET_LEN
	vdma_cram palette_start, 0, PALETTE_LEN

    mfdp dl
    xor a, a
    mtdp al

    ld b, board_buffer
    add b, GRID_START_POS * 2
    ld a, TILE_COVERED ; tile entry: second tile, nothing else

    .1:
    ld c, (COLUMNS - 1) * 2
    .0:
        st a, [b + c]
        sub c, 2
        jnc .0
        add b, 64
        cmp b, board_buffer + (GRID_START_POS + ((ROWS - 1) * 32) + (COLUMNS - 1)) * 2
        jltu .1

    mtdp dl

    vdma_vram board_buffer, 0, 2048

	xor al, al
	st  al, [PPUCTRL]
    mtdp al

main:
    jsr handle_input_movement
    ld a, [last_selected_cell]
    jsr calculate_cell_offset
    st a, [last_cell_vram_offset]

    ld a, [selected_cell]
    jsr calculate_cell_offset
    st a, [selected_cell_vram_offset]

    jsr handle_input_command

    wfi
    jsr advance_time
    jsr decode_time
    jsr print_time
	jrel main

setup_ivt:
	ld    al, .pageof rom_ivt_start
	ld    b, rom_ivt_start
	ld    cl, MMIO_PAGE
	xor   d, d
	ld    e, ROM_IVT_LEN
	blkcp [al:b], [cl:d], e
	rts

advance_time:
    ld b, frames_elapsed
    ld al, [b]
    inc al
    cmp al, 60
    jltu .0

    xor al, al
    st al, [b+]

    ld a, [b]
    inc a
    cmp a, 999
    jgtu .1
    st a, [b]
    .1:
    rts

    .0:
    st al, [b]
    rts

decode_time:
    ld b, time_digits
    xor al, al
    st al, [b+]
    st al, [b+]
    st al, [b]

    ld a, [seconds_elapsed]

    .0:
        cmp a, 0
        jz .1
        divu a, 10
        mfhi cl
        st cl, [b-]
        cmp b, time_digits
        jgeu .0

    .1:
    rts

print_time:
    push d
    ld a, time_digits
    ld b, board_buffer + 58
    ld dl, 3
    .0:
    ld cl, [a+]
    zxt cl
    add c, TILE_DIGIT_0 | (1 << 10) ; Convert to digit tile + second palette
    st c, [b+]
    djnz dl, .0
    pop d
    rts

; a -> board_buffer word offset of the clicked cell
; b -> grid address of the clicked cell
reveal_cell:
    shove push, d, e

    ld d, flood_queue
    st d, [queue_head]
    st d, [queue_tail]

    ld cl, [b]
    and cl, 0xF0
    st cl, [b]
    lsr cl, 4

    ld d, TILE_REVEALED
    st d, [a]

    cmp cl, 0
    jz .0

    ld d, TILE_DIGIT_0
    zxt cl
    add d, c
    st d, [a + 2048]
    jmp .1

    .0:
    xor d, d
    st d, [a + 2048]

    .1:
    ld d, [cells_remaining]
    dec d
    st d, [cells_remaining]

    cmp cl, 0
    jnz .3
    mov a, b
    jsr enqueue_neighbors

    ; drain the queue
    .2:
        ld a, [queue_head]
        ld d, [queue_tail]
        cmp a, d
        jz .3

        mov d, a
        ld a, [d]
        add d, 2
        st d, [queue_head]

        mov e, a
        jsr calculate_cell_offset
        mov c, a

        mov a, e
        add a, grid
        mov b, a

        ld al, [b]
        lsr al, 4

        ld d, TILE_REVEALED
        st d, [c]

        cmp al, 0
        jz .4

        ld d, TILE_DIGIT_0
        zxt al
        add d, a
        st d, [c + 2048]
        jmp .5

        .4:
        xor d, d
        st d, [c + 2048]

        .5:
        ld d, [cells_remaining]
        dec d
        st d, [cells_remaining]

        cmp al, 0
        jnz .2
        mov a, b
        jsr enqueue_neighbors
        jmp .2

    .3:
    shove pop, d, e
    rts

enqueue_neighbors:
    shove push, d, e, f, g
    mov g, a
    ld e, NEIGHBOR_OFFSETS_LEN - 1
    .0:
        ld.l fl, [neighbor_offsets + e]
        sxt fl

        mov d, g
        add d, f

        ld bl, [d]
        cmp bl, CELL_IS_BORDER
        jz .1

        bt bl, CELL_HAS_MINE
        jnz .1

        and bl, CELL_STATE_MASK
        cmp bl, CELL_REVEALED
        jz .1
        cmp bl, CELL_FLAGGED
        jz .1

        ld bl, [d] ; mark as revealed
        and bl, 0xF0
        st bl, [d]

        mov a, d
        sub a, grid
        jsr enqueue_cell

        .1:
        djnc e, .0

    shove pop, d, e, f, g
    rts

; a -> grid index to append to the queue
enqueue_cell:
    ld b, [queue_tail]
    st a, [b]
    add b, 2
    st b, [queue_tail]
    rts

game_over:
    ld al, MMIO_PAGE
    mtdp al
    ld a, 0x06F9
    st a, [NOIADSR]
    ld a, 100
    st a, [NOIRATE]
    ld al, 0b10
    st al, [NOICTRL]
    xor al, al
    mtdp al

    ld b, INNER_GRID_START

    .0:
        ld al, [b]
        cmp al, CELL_IS_BORDER
        jz .1

        bt al, CELL_HAS_MINE
        jz .1

        mov a, b
        sub a, grid

        push b
        jsr calculate_cell_offset

        add a, overlays_buffer
        ld b, TILE_MINE
        st b, [a]
        pop b

        .1:
        inc b
        cmp b, grid + (TOTAL_COLS * TOTAL_ROWS) - TOTAL_COLS
        jltu .0

    ld d, TILE_MINE_BOOM
    st d, [c]
    ld al, 255
    st al, [game_state]
    .2:
        wfi
        ld al, [0]
        cmp al, 0
        jz .3

        dec al
        st al, [0]
        jmp .2

        .3:
        xor al, al
        st.l al, [NOICTRL]
        ld.l a, [JOYPAD1]
        bt a, BTN_START
        jz .4
        jmp _start
        .4:
        jrel .2

; pressing B on an uncovered tile does nothing. Pressing B on a covered tile cycles:
; no overlay -> flag -> question
; new cell state gets stored in [b], overlay texture has to get stored in BG3 coordinates
handle_input_command:
    push d
    ld al, [command_input_delay_frames]
    cmp al, 0
    jz .5

    dec al
    st al, [command_input_delay_frames]
    jmp .0

    .5:
    ld a, [selected_cell]

    mov b, a
    add b, grid
    ld dl, [b]

    push b
    jsr calculate_cell_offset
    pop b

    mov c, a
    add c, overlays_buffer

    ld.l a, [JOYPAD1]
    
    bt a, BTN_START
    jz .10
    jmp _start

    .10:
    bt a, BTN_A
    jz .6

    ld al, [mines_placed]
    cmp al, 0
    jnz .9
    shove push, a, b, c
    jsr place_mines
    shove pop, a, b, c

    .9:
;------------------------------------------------------------------------------------
    ; a -> input state, garbo
    ; b -> grid index
    ; c -> overlays_buffer index
    ; dl -> selected cell state
;------------------------------------------------------------------------------------
    ld dl, [b]
    mov al, dl
    and dl, CELL_STATE_MASK

    cmp dl, CELL_REVEALED
    jz .0 ; A on revealed cell -> nothing

    cmp dl, CELL_FLAGGED
    jz .0 ; Same here

    bt al, CELL_HAS_MINE
    jz .7 ; no mine

    jsr game_over

    .7:
    ; if it's covered (even if it has a question mark), try to reveal it
    ; a -> board_buffer word offset
    ; b -> grid address
    mov a, c
    sub a, overlays_buffer
    jsr reveal_cell
    jmp .0

    .6:
    bt a, BTN_B
    jz .0 ; no usable input
    and dl, CELL_STATE_MASK
;------------------------------------------------------------------------------------
    ; a -> input state, garbo
    ; b -> grid index
    ; c -> overlays_buffer index
    ; dl -> selected cell state
;------------------------------------------------------------------------------------

    .1:
    cmp dl, CELL_COVERED
    jnz .2

    ; if covered with no marks, cycle to flag (tile 4)
    ld a, TILE_FLAG
    ld dl, CELL_FLAGGED
    jmp .4

    .2:
    cmp dl, CELL_FLAGGED
    jnz .3

    ; if it's flagged, cycle to question mark (tile 17)
    ld a, TILE_QUESTION
    ld dl, CELL_QUESTION
    jmp .4

    .3:
    cmp dl, CELL_QUESTION
    jnz .0

    ; if question mark, cycle back to no mark
    xor a, a
    ld dl, CELL_COVERED

    .4:
    st a, [c]
    ld al, [b]
    and al, 0xfc
    or al, dl
    st al, [b]
    ld al, 10
    st al, [command_input_delay_frames]

    .0:
    pop d
    rts

handle_input_movement:
    ld al, [movement_input_delay_frames]
    cmp al, 0
    jz .0

    dec al
    st al, [movement_input_delay_frames]
    jmp .5

    .0:
    ld.l a, [JOYPAD1]
    ld b, [selected_cell]
    st b, [last_selected_cell]

    ; up?
    bt a, BTN_UP
    jz .1 ; down?

    ; yes up
    sub b, TOTAL_COLS

    .1:
    bt a, BTN_DOWN
    jz .2 ; left?

    ; yes down
    add b, TOTAL_COLS

    .2:
    bt a, BTN_LEFT
    jz .3 ; right?

    ; yes left
    dec b

    .3:
    bt a, BTN_RIGHT
    jz .4 ; no input

    ; yes right
    inc b

    .4:
    ld al, 5
    st al, [movement_input_delay_frames]

    ld al, [b + grid]
    cmp al, CELL_IS_BORDER
    jz .5

    st b, [selected_cell]

    .5:
    rts

; calculate cell offset within vram and convert to inner grid coords
; a -> cell offset variable
; returns a -> offset value
calculate_cell_offset:
    mov b, a

    divu b, TOTAL_COLS ; outer grid row/column
    mfhi a

    dec b ; convert to inner row, inner column
    dec a

    lsl a, 1 ; word index
    lsl b, 6 ; 2 * 32 * row
    add a, b

    add a, GRID_START_POS * 2
    rts

seed_xorshift:
    ld a, [selected_cell]
    add a, [seconds_elapsed]

    ld bl, [frames_elapsed]
    zxt bl
    mulu a, b

    cmp a, 0
    jnz .0
    ld a, 0xDEAD

    .0:
    st a, [xorshift_state]
    rts

randi_xorshift:
    ld a, [xorshift_state]

    mov b, a
    lsl b, 7
    xor a, b

    mov b, a
    lsr b, 9
    xor a, b

    mov b, a
    lsl b, 8
    xor a, b

    st a, [xorshift_state]
    rts

place_mines:
    shove push, d, e, f
    jsr seed_xorshift

    ld f, MINE_COUNT
    .0:
        jsr randi_xorshift
        divu a, ROWS
        mfhi c ; row

        jsr randi_xorshift
        divu a, COLUMNS
        mfhi d ; column

        inc c
        inc d
        mulu c, TOTAL_COLS
        add c, d

        ld e, [selected_cell]
        cmp c, e
        jz .0

        add c, grid
        ld al, [c]
        bt al, CELL_HAS_MINE
        jnz .0

        or al, CELL_HAS_MINE
        st al, [c]
        djnz f, .0

    ld a, (TOTAL_ROWS * TOTAL_COLS) - 1
    ld b, grid
    .1:
        ld cl, [b + a]
        cmp cl, CELL_IS_BORDER
        jz .2

        bt cl, CELL_HAS_MINE
        jnz .2

        xor d, d
        ld e, NEIGHBOR_OFFSETS_LEN - 1
        .3:
            ld.l fl, [neighbor_offsets + e]
            sxt fl
            shove push, a, b
            add b, f
            add a, b
            jsr test_neighbor
            add dl, al
            shove pop, a, b
            djnc e, .3

        lsl dl, 4
        or cl, dl
        st cl, [b + a]
        .2:
            djnc a, .1

    ld al, 1
    st al, [mines_placed]
    ld a, (ROWS * COLUMNS) - MINE_COUNT
    st a, [cells_remaining]
    shove pop, d, e, f
    rts

; returns al = 1 if it is a mine
; takes in a -> pointer to cell
test_neighbor:
    ld al, [a]
    cmp al, CELL_IS_BORDER
    jz .0

    bt al, CELL_HAS_MINE
    jz .0

    ld al, 1
    jmp .1

    .0:
    xor al, al
    .1:
    rts

init_grid:
; First row, last row, first col, last col are all sentinel values 0x10
    ld al, CELL_IS_BORDER
    ld b, TOTAL_COLS - 1
    .0:
        st al, [b + grid]
        djnc b, .0

    ld b, grid + ((TOTAL_COLS * TOTAL_ROWS) - 1)
    .1:
        st al, [b-]
        cmp b, grid + (TOTAL_COLS * (TOTAL_ROWS - 1))
        jgeu .1

    ld b, grid + TOTAL_COLS
    .2:
        st al, [b]
        add b, TOTAL_COLS - 1
        st al, [b+]
        cmp b, grid + (TOTAL_COLS * (TOTAL_ROWS - 1))
        jltu .2

    ld al, CELL_COVERED
    ld b, INNER_GRID_START
    .3:
    ld c, COLUMNS
    .4:
        st al, [b+]
        djnz c, .4
    add b, 2
    cmp b, grid + ((TOTAL_ROWS - 1) * TOTAL_COLS) + 1
    jltu .3

    rts

render_cursor:
    ld a, [last_selected_cell]
    ld b, [last_cell_vram_offset]

    ld cl, [a + grid]
    and cl, CELL_STATE_MASK
    cmp cl, CELL_REVEALED
    jnz .0

    ld c, TILE_REVEALED
    jmp .1

    .0:
    ld c, TILE_COVERED

    .1:
    st c, [b + board_buffer]
 
    ld b, [selected_cell_vram_offset]
    ld c, TILE_CURSOR
    st c, [b + board_buffer]
    rts

_isr_vblnk:
    shove push, a, b, c, hi, dp
    jsr render_cursor

    ld al, MMIO_PAGE
    mtdp al
    vdma_vram board_buffer, 0, 4096

    shove pop, a, b, c, hi, dp
	rti

; ==================
;       DATA
; ==================

rom_ivt_start:
	.faraddr _isr_vblnk

rom_ivt_end:
	.equ ROM_IVT_LEN, rom_ivt_end - rom_ivt_start

tileset_start:
	.incbin "../build/assets/tileset.bin"
tileset_end:
	.equ TILESET_LEN, tileset_end - tileset_start
    .equ TILESET_VRAM_START, 2048 * 4

palette_start:
	.incbin "../build/assets/tileset.pal"
all_white_pal:
    .space 32, 0xff
palette_end:
	.equ PALETTE_LEN, palette_end - palette_start

neighbor_offsets:
    .byte -TOTAL_COLS - 1 ; up, left
    .byte -TOTAL_COLS ; up
    .byte -TOTAL_COLS + 1 ; up, right
    .byte -1 ; left
    .byte 1 ; right
    .byte TOTAL_COLS - 1 ; down, left
    .byte TOTAL_COLS ; down
    .byte TOTAL_COLS + 1 ; down, right
neighbor_offsets_end:
    .equ NEIGHBOR_OFFSETS_LEN, neighbor_offsets_end - neighbor_offsets
