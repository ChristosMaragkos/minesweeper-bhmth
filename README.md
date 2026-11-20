# Minesweeper for BHMTH

This is a "simple" minesweeper demo I wrote in a little less than 1000 lines of assembly for BHMTH.
It's not complete yet (game over hangs and winning does nothing), so I'll (hopefully have the will to) update it at some point.

## Running

- Download the ROM from the [releases](https://github.com/ChristosMaragkos/minesweeper-bhmth/releases/latest) page
- Grab the latest [BHMTH release](https://github.com/ChristosMaragkos/behemoth/releases/latest)
- `behemoth minesweeper.bhm`

Controls:

- Arrow keys to move cursor
- Z to flag a potential mine, Z again to turn it into a question mark, Z to clear
- X to reveal a cell
- Enter to restart

Game "ends" when you either reveal a cell with a mine on it or when you reveal all empty cells.

## Building from source

Before you build, you will need the `vasm` and `vlink` binaries vendored in the BHMTH repo. They are included with all releases (but windows support may be tricky as I haven't set it up yet)
This project uses GNU Make. Clone the repo, go into the root directory and simply run `make`.
The resulting binary goes into `bin/minesweeper.bhm`.
If the emulator is in your `PATH` you can also run `make run` to run the game.
