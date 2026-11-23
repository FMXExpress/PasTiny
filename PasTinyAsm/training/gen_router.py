#!/usr/bin/env python3
"""Requests and where they belong, for the PasTinyAsm router.

The router reads a request and says which expert should have it:

  screen sound text    one call
  tasks                a small program (the tasks and slots experts)
  recipes              "build an alarm clock"
  several              several steps in one sentence, to be split and routed one by one

A request is given in small letters, with its commas and single spaces,
and every digit shown as 0, so the router learns that a number is there
and not which one.

Splits:
  all     what the router is trained on: seen and new together, each said a little differently now and then
  seen    the wordings the experts were trained on
  valid   wordings the experts know and the router does not; they decide when its training stops
  new     wordings no expert was trained on; the word lists were mended on them, so the router gets them too
  fresh   wordings written after everything else was finished: new to the word lists too

  python3 gen_router.py N [all|seen|valid|new|fresh]
"""
import json, random, re, sys
import gen_asm, gen_recipes, gen_tasks

CLASSES = ['screen', 'sound', 'text', 'tasks', 'recipes', 'several']
JOIN = [', ', ' and ', ' then ', ' and then ', ', then ']


def tidy(s):
    """As the router is given a request: small letters, digits as 0, commas, single spaces."""
    return re.sub(r'\d', '0', re.sub(r'[^a-z0-9,]+', ' ', s.lower()).strip())


# Wordings written after the word lists and the experts were finished, and not used to
# train or to tune anything: neither the lists nor the router has seen them.
FRESH = {
    'screen': ['wipe the display', 'give me a {c} background', 'turn everything {c}', 'blank the screen out',
               'paint the screen {c}', 'jump to line {n} position {n}', 'i do not want to see the cursor',
               'bring the cursor back', 'let the screen blink {n} times', 'put a {c} frame around the screen',
               'make the letters {c}', 'start with an empty screen', 'set the cursor on row {n} and column {n}'.replace(' and ', ' '),
               'the writing should be {c}'],
    'sound': ['give me a tone', 'let me hear a siren', 'make some noise for {n} seconds', 'ring at {n} hertz',
              'do nothing for {n} seconds', 'stay quiet for a moment', 'hold on until i press something',
              'a short high tone', 'sound the alarm', 'play me a little melody', 'take a break of {n} ms',
              'buzz for half a second', 'let it ring', 'stop until a key is hit'],
    'text': ['put the words {t} on screen', 'tell the user {t}', 'the message is {t}', 'output a blank line',
             'write down {t}', 'let it say {t}', 'show the value {n}', 'greet with {t}', 'type out {t}',
             'put {n} on the screen', 'start a fresh line', 'show a message saying {t}', 'announce {t}',
             'print out the text {t}'],
    'tasks': ['go through {n} to {n} one by one', 'do a countdown starting at {n}', 'loop {n} times saying {w}',
              'read a number and show twice that number', 'read a number and beep if it is over {n}',
              'show the multiplication table of {n}', 'sum everything from 1 to {n}', 'draw a row of {n} stars',
              'beep whenever a key is pressed until q', 'ask the user for two numbers and show the larger',
              'count upwards to {n} beeping every time', 'show the first {n} square numbers',
              'ask for a number and count that far', 'say {w} {n} times in a row'],
    'recipes': ['make me {a}', 'can you build {a}', 'i need {a} program', 'please create {a}', 'give me {a} program',
                'i would like {a}', 'put together {a}', 'could you write {a} program'],
}
COLORS = ['blue', 'green', 'red', 'yellow', 'white', 'cyan', 'black']
WORDS = 'hello goodbye welcome friend ready winner sorry thanks morning player done yes'.split()
FILL = ['please ', 'now ', 'can you ', 'could you ', 'just ', 'i want to ', 'also ', 'lets ', 'next ', 'ok ']
TAIL = [' please', ' now', ' for me', ' right now', ' thanks']
SMALL = {'the', 'a', 'an', 'of', 'to', 'for', 'me', 'it', 'on', 'at'}


def fresh(r, c):
    q = r.choice(FRESH[c])
    while '{n}' in q:
        q = q.replace('{n}', str(r.randint(2, 900)), 1)
    q = q.replace('{c}', r.choice(COLORS)).replace('{w}', r.choice(WORDS))
    q = q.replace('{t}', ' '.join(r.sample(WORDS, r.randint(1, 3))))
    if '{a}' in q:
        name = r.choice(NAMES + [v[1] for v in gen_recipes.RECIPES.values()])
        q = q.replace('{a}', ('an ' if name[0] in 'aeiou' else 'a ') + name)
    return q


def single(r, split):
    e = r.choice(['screen', 'sound', 'text'])
    pool = {'seen': gen_asm.P[e] + gen_asm.V1[e], 'valid': gen_asm.V1HELD[e], 'new': gen_asm.HELD[e]}.get(split)
    while True:
        q = fresh(r, e) if split == 'fresh' else gen_asm.make(r, e, pool=pool)[0]
        if not re.search(r' (and|then) ', ' %s ' % q):       # that would be split in two
            return q, e


def vary(r, q):
    """The request said a little differently: a word in front or behind, a small word left out, a slip of the finger."""
    if r.random() < 0.25:
        q = r.choice(FILL) + q
    if r.random() < 0.12:
        q += r.choice(TAIL)
    w = q.split(' ')
    if r.random() < 0.2 and len(w) > 3:
        k = [i for i, x in enumerate(w) if x in SMALL]
        if k:
            del w[r.choice(k)]
    q = ' '.join(w)
    if r.random() < 0.1 and len(q) > 6:
        i = r.randrange(len(q))
        if q[i].isalpha():
            q = q[:i] + r.choice('abcdefghijklmnopqrstuvwxyz') + q[i + 1:]
    return q


NAMES = sorted((n for v in gen_recipes.RECIPES.values() for n in v[0]), key=len, reverse=True)


def relead(r, q):
    """"build a clock ..." as "write a clock program ..." or "i want a clock program ..."."""
    m = re.match(r'(?:build|create) ((?:an? )?)(.*)', q)
    name = next(n for n in NAMES if m.group(2).startswith(n))
    rest = m.group(2)[len(name):]
    if rest.startswith(' program'):
        rest = rest[8:]
    return r.choice(['write %s%s program', 'i want %s%s program']) % (m.group(1), name) + rest


def make(r, split='seen', raw=False):
    """One (request as the router sees it, class); raw: the request as typed."""
    if split == 'all':                 # what the router is trained on: everything the word lists were written with
        q, c = make(r, r.choice(['seen', 'seen', 'new']), raw=True)
        return (q if raw else tidy(vary(r, q))), c
    kind = r.choice(['one', 'one', 'one', 'tasks', 'tasks', 'recipes', 'several'])
    if kind == 'one':
        q, c = single(r, split)
    elif kind == 'tasks':
        how = {'seen': ['seen', 'seen', 'seen', 'far', 'quoted'], 'valid': ['words1'], 'new': ['words', 'combo']}.get(split)
        q, c = (fresh(r, 'tasks') if split == 'fresh' else gen_tasks.make(r, r.choice(how))[0]), 'tasks'
    elif kind == 'recipes':
        c = 'recipes'
        if split == 'fresh':
            q = fresh(r, c)
        else:
            q = gen_recipes.request(r, 'words' if split == 'new' else r.choice(['seen', 'combo']))[0]
            if split != 'new' and r.random() < 0.4:         # the other two ways of asking, with the names it knows
                q = relead(r, q)
    else:
        parts = [single(r, split)[0] for _ in range(r.randint(2, 4))]
        q = parts[0]
        for p in parts[1:]:
            q += r.choice(JOIN) + p
        c = 'several'
    if split == 'seen' and not raw:
        q = vary(r, q)
    return (q if raw else tidy(q)), c


if __name__ == '__main__':
    r = random.Random(1)
    for _ in range(int(sys.argv[1])):
        q, c = make(r, sys.argv[2] if len(sys.argv) > 2 else 'seen')
        print(json.dumps(dict(request=q, expert=c)))
