# Tic-tac-toe for DOS

Run `TICTAC.COM` for a local two-player game. Enter a square from 1 to 9 and press Enter. Squares are numbered left to right, top to bottom. The board shows 1 for X, 4 for O and 0 for an empty square. Enter 0 to quit.

To rebuild, copy TICTAC.SRC to your MAKECOM directory, then type `LOAD TICTAC` in MAKECOM. The source occupies 39 of the editor’s 40 lines. It uses nine variables for the board and checks all eight winning lines after each legal turn. The source was written in PasTinyAsm’s editor language after the natural-language request “make a two player tic tac toe game” was refused.

The 1,641-byte executable was built with the shipped Turbo Pascal MAKECOM and run in DOSBox-X. Tested an X win (1, 4, 2, 5, 3), an O win (1, 2, 3, 5, 4, 8), a draw (1, 2, 3, 5, 4, 6, 8, 7, 9), an occupied square, an out-of-range square and quitting.

# Go for DOS

Run `GO9.EXE` for a local two-player game on a 9×9 board. Black is X and White is O. Enter coordinates such as D4. Columns skip I. Enter PASS to pass or QUIT to leave.

The game handles captures, suicide and immediate ko. After two consecutive passes, it counts stones on the board and empty points surrounded by one color, with 6.5 komi for White. Play out disputed dead groups before passing. The scorer counts the final board as played.

Build with `TPC /B GO9.PAS`. The 81-point board and group traversal use Pascal arrays. This example is a standalone Turbo Pascal program. DOSBox-X tests covered a capture, immediate ko, suicide, an occupied point, quitting, and scoring after two passes.

## Go compiled by PasTinyAsm

[Download PASASM.ZIP](../dist/PASASM.ZIP) for the default XMS editor build, editable GOGAME.SRC and ready-to-play GOGAME.COM. Run GOGAME and enter the row and column as two digits. For example, 43 plays row 4, column 3. Enter 0 to pass and 100 to quit. Two passes score the final board by area with 6.5 komi for White. Play out disputed dead groups before passing.

In the bundled MAKECOM, type `LOAD GOGAME` to compile the 158-line editor program. It builds a standalone 6,697-byte COM. The board, group traversal, captures, suicide check, immediate ko, turn logic and scoring are written in the editor language. The game takes no model or XMS driver to play.

Build the editor with `TPC /B /DXMSSTREAM;GAMEARRAY MAKECOM.PAS`. This build adds space for 180 source lines and a 1,024-word array in each generated program. `GET variable index` reads a word. `PUT index expression` writes one. Literal indices must be in 0–1023. Calculated indices wrap modulo 1,024. The board program uses disjoint sections for the board, the rollback snapshot, the ko snapshot, visited flags and the traversal queue. The standard Turbo Pascal and QBasic exporters do not support these array statements.

DOSBox-X tests covered capture, immediate ko, occupied-point and suicide rejection, quitting and area scoring after two passes. The XMS editor had 301,160 bytes free after compiling the program.

## Chess compiled by PasTinyAsm

Run CHESS.COM for a local two-player chess prototype. Enter the source square, then the destination square. Each square is two digits in row-column order. For example, 25 followed by 45 plays e2–e4. Enter 0 at the source prompt to quit.

The 98-line CHESS.SRC implements ordinary piece moves, captures, blocked paths, turn handling, rejection of self-check and automatic queen promotion. The game does not implement castling, en passant, underpromotion, or automatic checkmate, stalemate and draw adjudication.

To reproduce the packaged COM, type `LOAD CHESS`, `TOP`, then `say welcome to chess` in the bundled MAKECOM. The last request uses the Text expert, whose generated PRINT instruction becomes the introductory line. The rules were written by hand in PasTinyAsm. The shipped editor refused the one-shot request “make a two player chess game”.

DOSBox-X verified legal moves, a capture, rejection of a blocked rook, and rejection of a move that leaves the king in check.
