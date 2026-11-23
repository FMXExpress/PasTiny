PasTinyAsm 1.0 - say what a program should do, get a .COM file
================================================================
Files: MAKECOM.EXE, MAKECOM.HLP, ASK.SCR, EXPERTS.CAT, SCREEN.BIN,
SOUND.BIN, TEXT.BIN, TASKS.BIN, SLOTS.BIN, RECIPES.BIN, EXPORT.EXE.
Keep them in one directory.  Needs a 386 and about 590 KB of free
conventional memory.  A coprocessor is optional.

  C:\ASM> MAKECOM
  type:  make screen flash, play sound      and press Enter
  the screen shows:   1 FLASH 3
                      2 BEEP 440 300
  press Alt-X, then
  C:\ASM> OUT

Separate the steps with commas, "and" or "then".  Things it knows:
  clear the screen            flash the screen 5 times
  make the screen blue        make the text yellow
  red border                  go to row 12 column 30
  hide the cursor             show the cursor
  beep                        beep at 880 hertz for half a second
  play a siren                play a tune
  wait two seconds            wait for a key
  say hello world             print "Hello, World!"
  print the number 1234       new line
  do it 3 times               (repeats the whole program)

Put text in double quotes to print it exactly as typed.
It may be several words inside a small program, and numbers may
be as big as you like:
  print "well done you" 7 times
  count from 250 to 4000 and beep each time

A whole sentence can ask for a small program:
  count down from 10 and beep each time then say liftoff
  ask for a number and print its double
  print the 7 times table
  3 times, each time say hi and flash

THE EDITOR.  Your program is always on the screen.  The blue line
is where new code goes: type a sentence there and press Enter.  It
is written to disk after every change.

Words before a colon open a block, and what you type next goes
inside it:
  repeat 3 times:          count from 1 to 10:      forever:
  if it is bigger than 5:  if the key is q:         else

  Up, Down       move the blue line, into and out of blocks
  Tab, Shift-Tab jump to the next or the previous block
  Home, End      top and bottom
  F2             change the line below: its code comes up on the
                 blue line; alter it or type a new sentence,
                 Enter.  (Enter on an empty line does the same.)
  Del            on an empty line: delete the line below, or the
                 whole block it opens
  Left, Right, Home, End, Del, Backspace
                 move and correct inside what you are typing
  Esc            clear what you typed
  F1             help         Alt-X or QUIT   leave
Typed commands: END leaves a block, NEW starts again, NAME file.

BE ASKED.  Type  make an adventure  (or  make a menu) and answer
the questions: what is seen first, which keys may be pressed, what
each key leads to.  Separate things with commas:
  you fall into a pit, game over, stop
Parts that start with beep, play, flash, clear, wait or stop are
done; anything else is printed.  If a part cannot be used you are
asked to say it another way; Enter alone prints it as typed.
CANCEL ends the questions.  They are in ASK.SCR: change them, or
add a kind of program of your own.

MAKECOM file starts with the lines of a file already entered.
MAKECOM < file runs without the editor (UP DOWN TAB GO n DEL n SHOW).

You can also type the language itself (LIST shows it):
  FOR I=1 TO 5:OUT I*I:NEXT
  INPUT A:IF A>10:ECHO big:ELSE:ECHO small:END

Commands: NAME file (program to write, OUT at first), LIST (the
calls and their limits), HELP, MEM, QUIT.

READ THE PLAN.  Each line shows what was written for a step.  A line
that does not compile or has the wrong numbers is refused and nothing
is written.  But a wording the experts have not seen can be
turned into the wrong call (for example a beep where you wanted a
siren), so check the lines before you run the program.  You can also
type calls yourself: FLASH 3, BEEP 440 300.

See README.md in the source for how it works and what was measured.
