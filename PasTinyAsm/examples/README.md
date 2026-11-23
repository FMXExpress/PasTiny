# Tic-tac-toe for DOS

Run `TICTAC.COM` for a local two-player game. Enter a square from 1 to 9 and press Enter. Squares are numbered left to right, top to bottom. The board shows 1 for X, 4 for O and 0 for an empty square. Enter 0 to quit.

To rebuild, copy TICTAC.SRC to your MAKECOM directory, then type `LOAD TICTAC` in MAKECOM. The source occupies 39 of the editor’s 40 lines. It uses nine variables for the board and checks all eight winning lines after each legal turn. The source was written in PasTinyAsm’s editor language after the natural-language request “make a two player tic tac toe game” was refused.

The 1,641-byte executable was built with the shipped Turbo Pascal MAKECOM and run in DOSBox-X. Tested an X win (1, 4, 2, 5, 3), an O win (1, 2, 3, 5, 4, 8), a draw (1, 2, 3, 5, 4, 6, 8, 7, 9), an occupied square, an out-of-range square and quitting.

# Go for DOS

Run `GO9.EXE` for a local two-player game on a 9×9 board. Black is X and White is O. Enter coordinates such as D4. Columns skip I. Enter PASS to pass or QUIT to leave.

The game handles captures, suicide and immediate ko. After two consecutive passes, it counts stones on the board and empty points surrounded by one color, with 6.5 komi for White. Play out disputed dead groups before passing. The scorer counts the final board as played.

Build with `TPC /B GO9.PAS`. The 81-point board and group traversal use Pascal arrays. This example is a standalone Turbo Pascal program. DOSBox-X tests covered a capture, immediate ko, suicide, an occupied point, quitting, and scoring after two passes.
