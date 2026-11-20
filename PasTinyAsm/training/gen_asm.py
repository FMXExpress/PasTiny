#!/usr/bin/env python3
"""Training and test steps for the three PasTinyAsm experts.

A step is one thing the user asked for, cleaned the way MAKECOM.PAS cleans it
(small letters, digits and single spaces only).  The answer is one call from
LIB.ASM, such as "FLASH 3" or "BEEP 440 300".

Each expert has a list of (wording, answer) patterns.  The wordings under
HELD are never trained on; they measure how the expert copes with new phrasing.

  python3 gen_asm.py EXPERT N [--held] [--seed S]     prints N steps as JSON lines
"""
import json, random, sys

WORDS = ('zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen '
         'sixteen seventeen eighteen nineteen twenty').split()
COLORS8 = [('black', 0), ('blue', 1), ('green', 2), ('cyan', 3), ('red', 4), ('magenta', 5), ('purple', 5),
           ('brown', 6), ('white', 7), ('grey', 7), ('gray', 7)]
COLORS16 = [('black', 0), ('blue', 1), ('green', 2), ('cyan', 3), ('red', 4), ('magenta', 5), ('purple', 5),
            ('brown', 6), ('grey', 7), ('gray', 7), ('dark grey', 8), ('dark gray', 8), ('light blue', 9),
            ('light green', 10), ('light cyan', 11), ('light red', 12), ('pink', 13), ('light magenta', 13),
            ('yellow', 14), ('white', 15)]
COMMON = ('hello world hi there good morning night day my name is tiny the a cat dog big small red sun moon '
          'star game over you win lose press start ready go stop yes no thank thanks bye goodbye welcome to '
          'dos computer this is test one two three it works done loading please wait error ok fine great '
          'happy birthday new year friend love music time now here we are again and or but not all your base '
          'score level player enter exit menu file save open run fast slow up down left right').split()


def count(r, top):
    """A count from 1 to top, as digits or as a word."""
    n = r.randint(1, top)
    return (WORDS[n] if n <= 20 and r.random() < 0.5 else str(n)), n


def duration(r, top_seconds):
    """A length of time and its milliseconds."""
    k = r.random()
    if k < 0.12:
        return 'half a second', 500
    if k < 0.55:
        s = r.randint(1, top_seconds)
        word = WORDS[s] if s <= 20 and r.random() < 0.4 else str(s)
        return '%s %s' % (word, 'second' if s == 1 else 'seconds'), s * 1000
    ms = r.choice([r.randrange(50, 2001, 50), r.randrange(100, 9001, 100), r.randint(10, 9999)])
    return '%d %s' % (ms, r.choice(['ms', 'milliseconds'])), ms


def hertz(r):
    f = r.choice([r.randrange(100, 2001, 100), r.randrange(50, 4001, 50), r.randrange(40, 9991, 10), r.randint(40, 9999)])
    return str(f), f


def text(r):
    while True:
        ws = []
        for _ in range(r.randint(1, 4)):
            k = r.random()
            if k < 0.7:
                ws.append(r.choice(COMMON))
            elif k < 0.9:
                ws.append(''.join(r.choice('abcdefghijklmnopqrstuvwxyz') for _ in range(r.randint(2, 7))))
            else:
                ws.append(str(r.randint(0, 9999)))
        t = ' '.join(ws)
        if len(t) <= 30:
            return t, t


SLOTS = {
    'n': lambda r: count(r, 20), 'c8': lambda r: r.choice(COLORS8), 'c16': lambda r: r.choice(COLORS16),
    'row': lambda r: count(r, 25), 'col': lambda r: (lambda n: (str(n), n))(r.randint(1, 80)),
    'f': hertz, 'd': lambda r: duration(r, 9), 'w': lambda r: duration(r, 60), 't': text,
    'num': lambda r: (lambda n: (WORDS[n] if n <= 20 and r.random() < 0.3 else str(n), n))(
        r.choice([r.randint(0, 20), r.randint(0, 999), r.randint(0, 65535)])),
}

P = {}      # expert -> trained patterns
HELD = {}   # expert -> patterns never trained on

P['screen'] = [
    ('clear the screen', 'CLS'), ('wipe the screen', 'CLS'), ('cls', 'CLS'), ('clear the display', 'CLS'),
    ('erase the screen', 'CLS'), ('blank the screen', 'CLS'), ('make the screen empty', 'CLS'), ('clear screen', 'CLS'),
    ('flash the screen {n} times', 'FLASH {n}'), ('make the screen flash {n} times', 'FLASH {n}'),
    ('blink the screen {n} times', 'FLASH {n}'), ('flash the display {n} times', 'FLASH {n}'),
    ('flash {n} times', 'FLASH {n}'), ('make screen flash', 'FLASH 3'), ('flash the screen', 'FLASH 3'),
    ('make the screen blink', 'FLASH 3'), ('screen flash', 'FLASH 3'), ('make the screen flash', 'FLASH 3'),
    ('flash the screen twice', 'FLASH 2'), ('flash the screen once', 'FLASH 1'), ('blink the screen twice', 'FLASH 2'),
    ('make the screen {c8}', 'COLOR {c8}'), ('turn the screen {c8}', 'COLOR {c8}'), ('{c8} screen', 'COLOR {c8}'),
    ('{c8} background', 'COLOR {c8}'), ('set the background to {c8}', 'COLOR {c8}'),
    ('paint the screen {c8}', 'COLOR {c8}'), ('color the screen {c8}', 'COLOR {c8}'),
    ('colour the screen {c8}', 'COLOR {c8}'), ('make the background {c8}', 'COLOR {c8}'),
    ('make the text {c16}', 'INK {c16}'), ('{c16} text', 'INK {c16}'), ('set the text color to {c16}', 'INK {c16}'),
    ('set the text colour to {c16}', 'INK {c16}'), ('turn the letters {c16}', 'INK {c16}'),
    ('turn the text {c16}', 'INK {c16}'),
    ('make the border {c16}', 'BORDER {c16}'), ('{c16} border', 'BORDER {c16}'),
    ('set the border to {c16}', 'BORDER {c16}'), ('set the border color to {c16}', 'BORDER {c16}'),
    ('set the border colour to {c16}', 'BORDER {c16}'),
    ('go to row {row} column {col}', 'GOTO {row} {col}'), ('move the cursor to row {row} column {col}', 'GOTO {row} {col}'),
    ('put the cursor at row {row} col {col}', 'GOTO {row} {col}'), ('cursor to {row} {col}', 'GOTO {row} {col}'),
    ('move to line {row} column {col}', 'GOTO {row} {col}'), ('move the cursor to the top left', 'GOTO 1 1'),
    ('put the cursor in the middle of the screen', 'GOTO 13 40'), ('cursor to the top', 'GOTO 1 1'),
    ('hide the cursor', 'HIDE'), ('turn the cursor off', 'HIDE'), ('no cursor', 'HIDE'), ('cursor off', 'HIDE'),
    ('remove the cursor', 'HIDE'),
    ('show the cursor', 'SHOW'), ('turn the cursor on', 'SHOW'), ('cursor on', 'SHOW'), ('bring the cursor back', 'SHOW'),
]
HELD['screen'] = [
    ('clean the screen', 'CLS'), ('erase everything on the display', 'CLS'), ('empty the display', 'CLS'),
    ('make the display flash {n} times', 'FLASH {n}'), ('blink the display', 'FLASH 3'),
    ('let the screen flash {n} times', 'FLASH {n}'), ('flash screen {n} times', 'FLASH {n}'),
    ('change the background to {c8}', 'COLOR {c8}'), ('make the display {c8}', 'COLOR {c8}'),
    ('give me a {c8} screen', 'COLOR {c8}'),
    ('change the text to {c16}', 'INK {c16}'), ('make the letters {c16}', 'INK {c16}'), ('{c16} letters', 'INK {c16}'),
    ('turn the border {c16}', 'BORDER {c16}'), ('give the screen a {c16} border', 'BORDER {c16}'),
    ('change the border to {c16}', 'BORDER {c16}'),
    ('place the cursor at row {row} column {col}', 'GOTO {row} {col}'), ('jump to row {row} column {col}', 'GOTO {row} {col}'),
    ('set the cursor to line {row} col {col}', 'GOTO {row} {col}'),
    ('make the cursor invisible', 'HIDE'), ('switch off the cursor', 'HIDE'), ('get rid of the cursor', 'HIDE'),
    ('make the cursor visible', 'SHOW'), ('switch the cursor on', 'SHOW'), ('display the cursor', 'SHOW'),
]

P['sound'] = [
    ('beep', 'BEEP 440 300'), ('play sound', 'BEEP 440 300'), ('play a sound', 'BEEP 440 300'),
    ('make a sound', 'BEEP 440 300'), ('make a beep', 'BEEP 440 300'), ('play a tone', 'BEEP 440 300'),
    ('play a beep', 'BEEP 440 300'),
    ('beep at {f} hertz', 'BEEP {f} 300'), ('play {f} hz', 'BEEP {f} 300'), ('play a tone of {f} hertz', 'BEEP {f} 300'),
    ('beep at {f} hz for {d}', 'BEEP {f} {d}'), ('play {f} hertz for {d}', 'BEEP {f} {d}'),
    ('play a tone of {f} hz for {d}', 'BEEP {f} {d}'), ('beep for {d}', 'BEEP 440 {d}'),
    ('play a sound for {d}', 'BEEP 440 {d}'), ('a high beep', 'BEEP 1000 300'), ('a low beep', 'BEEP 200 300'),
    ('play a high sound', 'BEEP 1000 300'), ('play a low sound', 'BEEP 200 300'), ('a long beep', 'BEEP 440 1000'),
    ('a short beep', 'BEEP 440 100'), ('make a short beep', 'BEEP 440 100'), ('play a long tone', 'BEEP 440 1000'),
    ('play a siren', 'SIREN 2'), ('sound the alarm', 'SIREN 2'), ('siren {n} times', 'SIREN {n}'),
    ('make a siren sound', 'SIREN 2'), ('sound the siren {n} times', 'SIREN {n}'), ('play an alarm', 'SIREN 2'),
    ('siren', 'SIREN 2'), ('play the siren {n} times', 'SIREN {n}'),
    ('play a scale', 'SCALE'), ('play a tune', 'SCALE'), ('play some notes', 'SCALE'), ('play music', 'SCALE'),
    ('play a melody', 'SCALE'),
    ('wait {w}', 'WAIT {w}'), ('pause for {w}', 'WAIT {w}'), ('sleep {w}', 'WAIT {w}'), ('delay {w}', 'WAIT {w}'),
    ('wait for {w}', 'WAIT {w}'), ('wait a second', 'WAIT 1000'), ('wait', 'WAIT 1000'), ('pause', 'WAIT 1000'),
    ('wait a moment', 'WAIT 1000'),
    ('wait for a key', 'KEY'), ('wait for a keypress', 'KEY'), ('press any key', 'KEY'),
    ('wait until a key is pressed', 'KEY'), ('wait for me to press a key', 'KEY'),
    ('repeat {n} times', 'REPEAT {n}'), ('do it {n} times', 'REPEAT {n}'), ('do all of that {n} times', 'REPEAT {n}'),
    ('repeat everything {n} times', 'REPEAT {n}'), ('do that twice', 'REPEAT 2'), ('repeat it', 'REPEAT 2'),
    ('repeat it twice', 'REPEAT 2'),
]
HELD['sound'] = [
    ('sound the speaker', 'BEEP 440 300'), ('make a noise', 'BEEP 440 300'),
    ('play a note at {f} hertz', 'BEEP {f} 300'), ('give a high beep', 'BEEP 1000 300'),
    ('make a long beep', 'BEEP 440 1000'), ('sound a tone of {f} hz for {d}', 'BEEP {f} {d}'),
    ('make a sound for {d}', 'BEEP 440 {d}'),
    ('make an alarm sound', 'SIREN 2'), ('run the siren {n} times', 'SIREN {n}'), ('police siren', 'SIREN 2'),
    ('play a little tune', 'SCALE'), ('play some music', 'SCALE'), ('play the scale', 'SCALE'),
    ('hold on for {w}', 'WAIT {w}'), ('pause {w}', 'WAIT {w}'), ('delay for {w}', 'WAIT {w}'),
    ('wait for a second', 'WAIT 1000'),
    ('wait for the user to hit a key', 'KEY'), ('pause until a key is pressed', 'KEY'), ('wait for any key', 'KEY'),
    ('run it {n} times', 'REPEAT {n}'), ('do the whole thing {n} times', 'REPEAT {n}'),
    ('repeat that {n} times', 'REPEAT {n}'),
]

P['text'] = [
    ('say {t}', 'PRINT {t}'), ('print {t}', 'PRINT {t}'), ('write {t}', 'PRINT {t}'), ('show {t}', 'PRINT {t}'),
    ('display {t}', 'PRINT {t}'), ('type {t}', 'PRINT {t}'), ('print the words {t}', 'PRINT {t}'),
    ('print the text {t}', 'PRINT {t}'), ('say the word {t}', 'PRINT {t}'),
    ('print the number {num}', 'NUMBER {num}'), ('show the number {num}', 'NUMBER {num}'),
    ('write the number {num}', 'NUMBER {num}'), ('number {num}', 'NUMBER {num}'),
    ('new line', 'NEWLINE'), ('start a new line', 'NEWLINE'), ('go to the next line', 'NEWLINE'),
    ('next line', 'NEWLINE'), ('line break', 'NEWLINE'), ('print a blank line', 'NEWLINE'), ('newline', 'NEWLINE'),
]
HELD['text'] = [
    ('output {t}', 'PRINT {t}'), ('write the text {t}', 'PRINT {t}'), ('show the words {t}', 'PRINT {t}'),
    ('display the text {t}', 'PRINT {t}'),
    ('display the number {num}', 'NUMBER {num}'), ('output the number {num}', 'NUMBER {num}'),
    ('move to a new line', 'NEWLINE'), ('begin a new line', 'NEWLINE'), ('skip a line', 'NEWLINE'),
]

# Patterns with a slot are drawn more often, because they have far more to teach.
def make(r, expert, held=False):
    pats = (HELD if held else P)[expert]
    weights = [6 if '{' in q else 1 for q, _ in pats]
    while True:
        q, a = r.choices(pats, weights)[0]
        for name in SLOTS:
            if '{%s}' % name in q:
                shown, value = SLOTS[name](r)
                q = q.replace('{%s}' % name, shown); a = a.replace('{%s}' % name, str(value))
        if r.random() < 0.15 and not held and not a.startswith('PRINT'):
            q = 'please ' + q
        if len(q) <= 72:
            return q, a


if __name__ == '__main__':
    args = sys.argv[1:]
    seed = int(args[args.index('--seed') + 1]) if '--seed' in args else 1
    r = random.Random(seed)
    for _ in range(int(args[1])):
        q, a = make(r, args[0], '--held' in args)
        print(json.dumps(dict(question=q, answer=a)))
