#!/usr/bin/env python3
"""Training and test requests for the PasTinyAsm tasks expert.

The request is one sentence asking for a small program; the answer is that
program as one line of the PasTinyAsm language, for example

    count down from 10 and beep each time then say liftoff
    FOR I=10 DOWNTO 1:OUT I:BEEP:NEXT:ECHO liftoff

A program is built from parts: a head (count up, count down, N times, ask for
a number ...), an optional action for each round, and an optional action at the
end.  Some COMBINATIONS of parts are held out of training, although every part
is trained in other combinations.  They answer the question this experiment is
about: can the expert put known parts together in a way it has not seen?

  python3 gen_tasks.py N [seen|combo|words] [--seed S]     prints JSON lines
"""
import json, random, sys

WORDS = ('zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen '
         'sixteen seventeen eighteen nineteen twenty').split()
SAY = 'done ok hello bye liftoff go stop ready boom hi finished end yes start over'.split()
LIMIT = 126           # request + answer; the model's window is 128 with two end marks

# name -> (ways to say it, code)
ACTS = {
    'beep': (['beep', 'make a beep'], 'BEEP'),
    'flash': (['flash', 'flash the screen'], 'FLASH'),
    'wait': (['wait a second', 'pause a second'], 'WAIT'),
    'half': (['wait half a second', 'pause half a second'], 'WAIT 500'),
    'siren': (['play a siren', 'sound the siren'], 'SIREN'),
    'tune': (['play a tune', 'play a scale'], 'SCALE'),
    'say': (['say {t}', 'print {t}'], 'ECHO {t}'),
}
EACH = ['beep', 'flash', 'wait', 'half']                    # allowed inside a counting loop
END = ['beep', 'flash', 'siren', 'tune', 'say']             # allowed after it
ALL = list(ACTS)

_r = random.Random(20261121)                                # fixes which combinations are held out
COUNT_HELD = set(_r.sample([(d, e, f) for d in 'ud' for e in EACH for f in END], 10))
TIMES_HELD = set(_r.sample([(a, b) for a in ALL for b in ALL if a != b], 8))
ASKTIMES_HELD = {'siren', 'half'}
# held out as a class: "ask for a number and count ..." with BOTH an each-action and an end-action


def num(r, lo, hi):
    n = r.randint(lo, hi)
    return (WORDS[n] if n <= 20 and r.random() < 0.35 else str(n)), n


def act(r, name):
    said, code = ACTS[name]
    t = r.choice(SAY)
    return r.choice(said).replace('{t}', t), code.replace('{t}', t)


def tail(r, each, end):
    """The words and code for an each-round action and an end action (either may be None)."""
    q, body, after = '', '', ''
    if each:
        s, c = act(r, each)
        q += ' and %s %s time' % (s, r.choice(['each', 'every']))
        body = ':' + c
    if end:
        s, c = act(r, end)
        q += r.choice([' then %s', ' and %s at the end']) % s
        after = ':' + c
    return q, body, after


def count(r, held, words):
    while True:
        d = r.choice('ud')
        each = r.choice([None] + EACH); end = r.choice([None] + END)
        if ((d, each, end) in COUNT_HELD) != held:
            continue
        break
    if d == 'u':
        if r.random() < 0.4:
            (sb, b) = num(r, 2, 100); a = 1
            q = r.choice(['count to %s', 'print the numbers up to %s', 'count up to %s']) % sb
        else:
            a = r.randint(0, 60); b = a + r.randint(1, 40)
            q = r.choice(['count from %d to %d', 'count up from %d to %d', 'print the numbers from %d to %d']) % (a, b)
        if words:
            q = 'show every number from %d to %d' % (a, b)
        code = 'FOR I=%d TO %d' % (a, b)
    else:
        if r.random() < 0.5:
            (sa, a) = num(r, 2, 100); b = 1
            q = r.choice(['count down from %s', 'countdown from %s', 'count backwards from %s']) % sa
        else:
            b = r.randint(0, 60); a = b + r.randint(1, 40)
            q = r.choice(['count down from %d to %d', 'count from %d down to %d']) % (a, b)
        if words:
            q = 'count from %d back to %d' % (a, b)
        code = 'FOR I=%d DOWNTO %d' % (a, b)
    tq, body, after = tail(r, each, end)
    return q + tq, code + ':OUT I' + body + ':NEXT' + after


def times(r, held, words):
    while True:
        a = r.choice(ALL); b = r.choice([None] + ALL)
        if b == a or (((a, b) in TIMES_HELD) != held):
            continue
        break
    sn, n = num(r, 2, 20)
    sa, ca = act(r, a)
    said, code = sa, ca
    if b:
        sb, cb = act(r, b)
        said += r.choice([' and ', ' then ']) + sb; code += ':' + cb
    q = r.choice(['%s times, each time %s' % (sn, said), 'each time %s, %s times' % (said, sn),
                  'every time %s, do it %s times' % (said, sn)])
    if words:
        q = 'in each of %s rounds %s' % (sn, said)
    return q, 'TIMES %d:%s:END' % (n, code)


def ask(r, held, words):
    lead = r.choice(['ask for a number and ', 'ask me for a number then '])
    if words:
        lead = 'ask the user for a number and '
    kind = r.choice(['op', 'op', 'two', 'times', 'count', 'count'])
    if held and kind in ('op', 'two'):
        kind = r.choice(['times', 'count'])
    if kind == 'op':
        k = r.randint(2, 12)
        said, expr = r.choice([('print it', 'A'), ('print its double', 'A*2'), ('print its square', 'A*A'),
                               ('print half of it', 'A/2'), ('print it plus %d' % k, 'A+%d' % k),
                               ('print it times %d' % k, 'A*%d' % k), ('print it minus %d' % k, 'A-%d' % k)])
        return lead + said, 'INPUT A:OUT ' + expr
    if kind == 'two':
        said, expr = r.choice([('sum', 'A+B'), ('product', 'A*B'), ('difference', 'A-B')])
        return r.choice(['ask for two numbers and print their %s', 'ask me for two numbers then print their %s']) % said, \
            'INPUT A:INPUT B:OUT ' + expr
    if kind == 'times':
        while True:
            a = r.choice(ALL)
            if (a in ASKTIMES_HELD) == held:
                break
        sa, ca = act(r, a)
        return lead + sa + ' that many times', 'INPUT A:TIMES A:%s:END' % ca
    while True:
        each = r.choice([None] + EACH); end = r.choice([None] + END)
        if (each is not None and end is not None) == held:
            break
    d = r.choice('ud')
    q = lead + (r.choice(['count to it', 'count up to it']) if d == 'u' else 'count down from it')
    code = 'INPUT A:FOR I=1 TO A' if d == 'u' else 'INPUT A:FOR I=A DOWNTO 1'
    tq, body, after = tail(r, each, end)
    return q + tq, code + ':OUT I' + body + ':NEXT' + after


def other(r, held, words):
    """Shapes with no held-out combination: tables, sums and sound or colour patterns."""
    k = r.randint(2, 12); sn, n = num(r, 2, 20); b = r.randint(2, 100)
    return r.choice([
        ('print the %d times table' % k, 'FOR I=1 TO 10:OUT I*%d:NEXT' % k),
        ('print the squares from 1 to %d' % b, 'FOR I=1 TO %d:OUT I*I:NEXT' % b),
        ('add up the numbers from 1 to %d' % b, 'LET S=0:FOR I=1 TO %d:LET S=S+I:NEXT:OUT S' % b),
        ('print the first %s even numbers' % sn, 'FOR I=1 TO %d:OUT I*2:NEXT' % n),
        ('print the first %s odd numbers' % sn, 'FOR I=1 TO %d:OUT I*2-1:NEXT' % n),
        ('beep higher and higher %s times' % sn, 'FOR I=1 TO %d:BEEP I*100+200 100:NEXT' % n),
        ('beep lower and lower %s times' % sn, 'FOR I=%d DOWNTO 1:BEEP I*100+200 100:NEXT' % n),
        ('cycle through the colors', 'FOR I=0 TO 7:COLOR I:WAIT 300:NEXT'),
        ('cycle through the colors %s times' % sn, 'TIMES %d:FOR I=0 TO 7:COLOR I:WAIT 300:NEXT:END' % n),
        ('ask for a number and beep if it is bigger than %d' % b, 'INPUT A:IF A>%d:BEEP:END' % b),
        ('ask for a number and say yes if it is %d otherwise no' % b, 'INPUT A:IF A=%d:ECHO yes:ELSE:ECHO no:END' % b),
    ])


def make(r, split='seen'):
    """One (request, program).  split: 'seen' = trained combinations, 'combo' =
    held-out combinations of trained parts, 'words' = new wordings of heads."""
    held, words = split == 'combo', split == 'words'
    while True:
        fam = r.choice([count, count, times, ask] + ([] if held or words else [other]))
        q, a = fam(r, held, words)
        if len(q) <= 72 and len(q) + len(a) <= LIMIT:
            return q, a


if __name__ == '__main__':
    args = sys.argv[1:]
    r = random.Random(int(args[args.index('--seed') + 1]) if '--seed' in args else 1)
    split = args[1] if len(args) > 1 and not args[1].startswith('--') else 'seen'
    for _ in range(int(args[0])):
        q, a = make(r, split)
        print(json.dumps(dict(question=q, answer=a)))
