# Tic-tac-toe for DOS

Run `TICTAC.COM` for a local two-player game. Enter a square from 1 to 9 and press Enter. Squares are numbered left to right, top to bottom. The board shows 1 for X, 4 for O and 0 for an empty square. Enter 0 to quit.

To rebuild, copy TICTAC.SRC to your MAKECOM directory, then type `LOAD TICTAC` in MAKECOM. The source occupies 39 of the editor’s 40 lines. It uses nine variables for the board and checks all eight winning lines after each legal turn. The source was written in PasTinyAsm’s editor language after the natural-language request “make a two player tic tac toe game” was refused.

The 1,641-byte executable was built with the shipped Turbo Pascal MAKECOM and run in DOSBox-X. Tested an X win (1, 4, 2, 5, 3), an O win (1, 2, 3, 5, 4, 8), a draw (1, 2, 3, 5, 4, 6, 8, 7, 9), an occupied square, an out-of-range square and quitting.
