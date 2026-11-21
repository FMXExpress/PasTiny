#!/usr/bin/env python3
"""Training and test questions for the PasTinyAsm recipes expert.

A request such as "build an alarm clock" says little.  The expert knows what
such a thing consists of and says it in sentences the other experts
understand.  It is asked for one step at a time, and each question carries
the start of the step before, so that the expert only has to say what comes
next:

    1 alarm clock | start                 ->  ask for a number and count down from it and wait a second each time
    2 alarm clock | ask for a number and  ->  play a siren
    3 alarm clock | play a siren          ->  flash the screen 3 times
    4 alarm clock | flash the screen 3 ti ->  done

A question may be 72 characters long, so the request is cut to its core
("build a", "program" and the like are dropped) and only the first 20
characters of the previous step are given.  The first version asked with the
step number and the whole request and nothing else; see the README for how
the two compare.

A request is a recipe, perhaps with a number, and perhaps one change: done N
times, with something at the end, or on a coloured screen.  A change moves or
adds steps, so the same recipe gives different answers to "step 2".  Some
(recipe, change) pairs are held out of training; every recipe and every
change is trained in other pairs.

Splits:
  seen    trained recipes and pairs, fresh numbers
  combo   held-out (recipe, change) pairs
  words   names and request wordings never trained on

  python3 gen_recipes.py N [seen|combo|words] [--seed S]    prints JSON lines, one per step
"""
import json, random, re, sys

# name -> (names it goes by, a name used only for testing, how its number is said or None,
#          (lowest, highest number), the steps; {n} is the number)
RECIPES = {
    'alarm': (['alarm clock', 'alarm'], 'wake up alarm', None, None,
              ['ask for a number and count down from it and wait a second each time', 'play a siren', 'flash the screen 3 times']),
    'timer': (['kitchen timer', 'egg timer'], 'cooking timer', 'for {n} seconds', (3, 60),
              ['a timer for {n} seconds', 'play a tune']),
    'metronome': (['metronome'], 'beat keeper', 'with {n} beats', (4, 20),
                  ['repeat {n} times:', 'a short beep', 'wait half a second', 'end']),
    'traffic': (['traffic light', 'traffic lights'], 'stop light', None, None,
                ['make the screen red', 'wait 2 seconds', 'make the screen brown', 'wait a second', 'make the screen green', 'wait 2 seconds']),
    'doorbell': (['doorbell', 'door bell'], 'door chime', None, None,
                 ['beep at 660 hertz for 400 ms', 'beep at 520 hertz for 600 ms']),
    'police': (['police car', 'police lights'], 'cop car', 'with {n} flashes', (2, 12),
               ['repeat {n} times:', 'make the screen red', 'play a siren', 'make the screen blue', 'wait half a second', 'end']),
    'sos': (['sos signal', 'sos'], 'distress signal', None, None,
            ['beep 3 times fast', 'beep 3 times slowly', 'beep 3 times fast']),
    'launch': (['rocket launch', 'launch countdown'], 'space launch', 'from {n}', (3, 20),
               ['count down from {n} and beep each time then say liftoff', 'flash the screen 3 times']),
    'greeting': (['greeting', 'hello program'], 'welcome message', None, None,
                 ['clear the screen', 'say hello', 'new line', 'play a tune']),
    'quiz': (['times table trainer', 'times table'], 'multiplication helper', 'for {n}', (2, 12),
             ['print the {n} times table', 'wait for a key']),
    'guess': (['guessing game', 'number guessing game'], 'guess the number game', 'for {n}', (1, 100),
              ['keep asking for a number until it is {n}', 'play a tune']),
    'piano': (['piano', 'beep machine'], 'key beeper', None, None,
              ['each time i press a key beep, until q']),
    'rainbow': (['rainbow', 'color show'], 'colour parade', None, None,
                ['cycle through the colors', 'cycle through the border colors']),
    'fireworks': (['fireworks', 'firework show'], 'new year fireworks', 'with {n} rockets', (2, 12),
                  ['repeat {n} times:', 'flash the screen', 'a high beep', 'end', 'play a rising tone']),
    'clock': (['ticking clock', 'clock tick'], 'tick tock', 'for {n} ticks', (3, 30),
              ['repeat {n} times:', 'a short beep', 'wait a second', 'end']),
    'counter': (['counter', 'counting program'], 'number counter', 'to {n}', (2, 100),
                ['count to {n}', 'say done']),
    'tree': (['star tree', 'christmas tree'], 'pine tree', 'with {n} lines', (2, 12),
             ['print a triangle of stars with {n} lines', 'print a row of 3 stars']),
    'adder': (['adding machine', 'calculator'], 'sum machine', None, None,
              ['ask for two numbers and print their sum']),
    'doubler': (['doubling machine', 'doubler'], 'times two machine', None, None,
                ['ask for a number and print its double']),
    'checker': (['size checker', 'number checker'], 'big number test', 'for {n}', (1, 100),
                ['ask for a number and say yes if it is bigger than {n} otherwise say no']),
    'stopwatch': (['stopwatch', 'reaction test'], 'stop clock', None, None,
                  ['wait for a key', 'say go', 'wait for a key', 'say stop']),
    'welcome': (['welcome screen', 'title screen'], 'start screen', None, None,
                ['make the screen blue', 'make the text yellow', 'go to row 12 column 30', 'say welcome', 'wait for a key']),
    'warning': (['warning screen', 'danger sign'], 'alert screen', None, None,
                ['make the screen red', 'say stop', 'play a siren']),
    'squares': (['number cruncher', 'squares and cubes'], 'power lister', 'up to {n}', (2, 30),
                ['print the squares from 1 to {n}', 'print the cubes from 1 to {n}']),
    'night': (['night mode', 'dark mode'], 'evening mode', None, None,
              ['make the screen black', 'make the text green', 'hide the cursor']),
    'disco': (['disco', 'disco lights'], 'dance floor', 'with {n} rounds', (2, 12),
              ['cycle through the colors {n} times', 'play a tune']),
    'bigger': (['bigger number finder', 'max finder'], 'largest picker', None, None,
               ['ask for two numbers and print the bigger one']),
    'stars': (['star square', 'box of stars'], 'star block', 'of size {n}', (2, 12),
              ['print a square of stars {n} by {n}']),
    'sum': (['sum machine', 'total machine'], 'adding loop', 'up to {n}', (2, 100),
            ['add up the numbers from 1 to {n}', 'play a tune']),
    'lullaby': (['lullaby', 'music box'], 'cradle song', None, None,
                ['play a tune', 'wait a second', 'play a tune']),
}
COLORS = ['blue', 'green', 'red', 'black', 'cyan']
ENDS = [('with a beep at the end', 'beep'), ('then play a tune', 'play a tune'), ('with a siren at the end', 'play a siren')]
# changes: none; 'rep' = the whole thing N times; 'end' = one more step at the end; 'col' = a coloured screen first
CHANGES = ['rep', 'end', 'col']

_r = random.Random(20261122)                    # fixes which pairs are held out
HELD = set(_r.sample([(n, c) for n in RECIPES for c in CHANGES], 22))


def request(r, split='seen'):
    """A request and its steps.  Returns (request text, [steps])."""
    held, words = split == 'combo', split == 'words'
    while True:
        name = r.choice(list(RECIPES)); change = r.choice([None, None] + CHANGES)
        if words and change is not None and (name, change) in HELD:
            continue
        if not words and (change is not None and (name, change) in HELD) != held:
            continue
        names, test_name, how, rng, steps = RECIPES[name]
        said = test_name if words else r.choice(names)
        article = 'an ' if said[0] in 'aeiou' else 'a '
        if said.endswith('s') and said not in ('sos',) and name in ('fireworks', 'traffic', 'police', 'squares', 'disco'):
            article = ''
        q = (r.choice(['write %s%s program', 'i want %s%s program']) if words else
             r.choice(['build %s%s', 'create %s%s', 'build %s%s program'])) % (article, said)
        steps = list(steps)
        if how:
            n = r.randint(*rng)
            q += ' ' + how.replace('{n}', str(n))
            steps = [s.replace('{n}', str(n)) for s in steps]
        if change == 'rep':
            k = r.randint(2, 9)
            q += ', %d times' % k
            steps = ['repeat %d times:' % k] + steps + ['end']
        elif change == 'end':
            said_end, step = r.choice(ENDS)
            q += ' ' + said_end
            steps = steps + [step]
        elif change == 'col':
            c = r.choice(COLORS)
            q += ' on a %s screen' % c
            steps = ['make the screen %s' % c] + steps
        if len(q) <= 68 and len(steps) <= 11 and all(len('%d %s' % (len(steps) + 1, q)) + len(s) <= 124 for s in steps):
            return q, steps


def tidy(s):
    """As MAKECOM tidies a request: small letters, digits and single spaces."""
    return re.sub(r'[^a-z0-9]+', ' ', s.lower()).strip()


def core(q):
    """The request without the words that only say "make me one"."""
    t = tidy(q)
    for lead in ('build ', 'create ', 'write ', 'i want '):
        if t.startswith(lead):
            t = t[len(lead):]
    for lead in ('an ', 'a '):
        if t.startswith(lead):
            t = t[len(lead):]
    return t.replace(' program', '', 1)


def question(k, q, steps):
    """The question for step k (from 1) of request q, whose steps so far are known."""
    prev = 'start' if k == 1 else tidy(steps[k - 2])[:20].strip()
    return '%d %s | %s' % (k, core(q), prev)


def fits(q, steps):
    """Can every step of this request be asked for and answered inside the window?"""
    return all(len(question(k, q, steps)) <= 72 and len(question(k, q, steps)) + len(steps[k - 1]) <= 124
               for k in range(1, len(steps) + 1)) and len(question(len(steps) + 1, q, steps)) <= 72


def make(r, split='seen'):
    """One (question, answer): a step of a request, or "done" after its last."""
    while True:
        q, steps = request(r, split)
        if fits(q, steps):
            break
    k = r.randint(1, len(steps) + 1)
    return question(k, q, steps), steps[k - 1] if k <= len(steps) else 'done'


if __name__ == '__main__':
    args = sys.argv[1:]
    r = random.Random(int(args[args.index('--seed') + 1]) if '--seed' in args else 1)
    split = args[1] if len(args) > 1 and not args[1].startswith('--') else 'seen'
    for _ in range(int(args[0])):
        q, a = make(r, split)
        print(json.dumps(dict(question=q, answer=a)))
