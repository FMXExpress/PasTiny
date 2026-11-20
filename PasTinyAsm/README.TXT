PasTinyAsm 1.0 - say what a program should do, get a .COM file
================================================================
Files: MAKECOM.EXE, EXPERTS.CAT, SCREEN.BIN, SOUND.BIN, TEXT.BIN.
Keep them in one directory.  Needs a 386 and about 570 KB of free
conventional memory.  A coprocessor is optional.

  C:\ASM> MAKECOM
  > make screen flash, play sound
  1 make screen flash -> FLASH 3
  2 play sound -> BEEP 440 300
  wrote OUT.COM 123 bytes, OUT.ASM
  > quit
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

Commands: NAME file (program to write, OUT at first), LIST (the
calls and their limits), HELP, MEM, QUIT.

READ THE PLAN.  Each line shows the call chosen for a step.  A call
that is unknown, out of range or has the wrong numbers is refused and
nothing is written.  But a wording the experts have not seen can be
turned into the wrong call (for example a beep where you wanted a
siren), so check the lines before you run the program.  You can also
type calls yourself: FLASH 3, BEEP 440 300.

See README.md in the source for how it works and what was measured.
