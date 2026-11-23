#!/usr/bin/env python3
"""Training and test requests for the PasTinyAsm tasks expert.

The request is one sentence asking for a small program; the answer is that
program as one line of the PasTinyAsm language, for example

    count down from 10 and beep each time then say liftoff
    FOR I=10 DOWNTO 1:OUT I:BEEP:NEXT:ECHO liftoff

A program is built from parts: a head (count up, count down, N times, ask for
a number, test a number ...), actions inside it, and an action at the end.
Some COMBINATIONS of parts are held out of training, although every part is
trained in other combinations.  They measure whether the expert can put known
parts together in a way it has not seen.

Splits:
  seen    trained combinations and shapes, fresh numbers and texts
  combo   held-out combinations of trained parts
  words1  the first version's held-out wordings, which are trained on now
  words   wordings never trained on
  far     trained shapes with numbers far outside the trained ranges
  quoted  trained shapes whose text is several words in double quotes

SLOTS.  The expert does not see the numbers of a request, nor a text that
is in quotes.  The program swaps them for markers before asking (n1, n2
... for numbers in the order they come, t1 ... for texts) and puts the
values back into the answer:

    count from 3 to 17 and say "all done" at the end
    count from n1 to n2 and say t1 at the end
    FOR I=n1 TO n2:OUT I:NEXT:ECHO t1

So the expert never copies a number or a quoted text, and any number will
do.  slot() below is the same rule as Slot in MAKECOM.PAS.  A text that is
not in quotes is left as the word it is; in training about half the texts
are markers.

  python3 gen_tasks.py N [seen|combo|words1|words] [--seed S]     prints JSON lines
"""
import json, random, re, sys

WORDS = ('zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen '
         'sixteen seventeen eighteen nineteen twenty').split()
SAY = 'done ok hello bye liftoff go stop ready boom hi finished end yes no big small high low start over'.split()
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
TESTS = [('bigger than', '>'), ('more than', '>'), ('smaller than', '<'), ('less than', '<'),
         ('equal to', '='), ('', '='), ('not', '<>'), ('at least', '>='), ('at most', '<=')]

_r = random.Random(20261121)                                # fixes which combinations are held out
COUNT_HELD = set(_r.sample([(d, e, f) for d in 'ud' for e in EACH for f in END], 10))
TIMES_HELD = set(_r.sample([(a, b) for a in ALL for b in ALL if a != b], 8))
ASKTIMES_HELD = {'siren', 'half'}
IF_HELD = set(_r.sample([(op, a) for op in ('>', '<', '=', '<>', '>=', '<=') for a in ALL], 9))
# held out as classes: "ask for a number and count ..." with BOTH an each-action and an
# end-action, and "ask for a number and A if ... otherwise B" where A and B are both
# actions (every test and every action is trained with only one of them)


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
        q += r.choice([' then %s', ' and %s at the end', ' and finally %s']) % s
        after = ':' + c
    return q, body, after


def ask_lead(r, split):
    if split == 'words':
        return 'ask for one number and '
    if split == 'words1':
        return 'ask the user for a number and '
    return r.choice(['ask for a number and ', 'ask me for a number then ', 'ask the user for a number and ',
                     'ask for a number then '])


def count(r, held, split):
    while True:
        d = r.choice('ud')
        each = r.choice([None] + EACH); end = r.choice([None] + END)
        if ((d, each, end) in COUNT_HELD) == held:
            break
    if d == 'u':
        a = r.randint(0, 60); b = a + r.randint(1, 40)
        if split == 'words':
            q = 'run through the numbers from %d to %d' % (a, b)
        elif split == 'words1':
            q = 'show every number from %d to %d' % (a, b)
        elif r.random() < 0.35:
            (sb, b) = num(r, 2, 100); a = 1
            q = r.choice(['count to %s', 'print the numbers up to %s', 'count up to %s', 'list the numbers up to %s']) % sb
        else:
            q = r.choice(['count from %d to %d', 'count up from %d to %d', 'print the numbers from %d to %d',
                          'show every number from %d to %d', 'list the numbers from %d to %d']) % (a, b)
        code = 'FOR I=%d TO %d' % (a, b)
    else:
        b = r.randint(0, 60); a = b + r.randint(1, 40)
        if split == 'words':
            q = 'go backwards from %d to %d' % (a, b)
        elif split == 'words1':
            q = 'count from %d back to %d' % (a, b)
        elif r.random() < 0.45:
            (sa, a) = num(r, 2, 100); b = 1
            q = r.choice(['count down from %s', 'countdown from %s', 'count backwards from %s']) % sa
        else:
            q = r.choice(['count down from %d to %d', 'count from %d down to %d', 'count from %d back to %d',
                          'print the numbers from %d down to %d']) % (a, b)
        code = 'FOR I=%d DOWNTO %d' % (a, b)
    tq, body, after = tail(r, each, end)
    return q + tq, code + ':OUT I' + body + ':NEXT' + after


def times(r, held, split):
    while True:
        a = r.choice(ALL); b = r.choice([None] + ALL)
        if b != a and (((a, b) in TIMES_HELD) == held):
            break
    sn, n = num(r, 2, 20)
    sa, ca = act(r, a)
    said, code = sa, ca
    if b:
        sb, cb = act(r, b)
        said += r.choice([' and ', ' then ']) + sb; code += ':' + cb
    if split == 'words':
        q = 'for %s rounds %s' % (sn, said)
    elif split == 'words1':
        q = 'in each of %s rounds %s' % (sn, said)
    else:
        q = r.choice(['%s times, each time %s' % (sn, said), 'each time %s, %s times' % (said, sn),
                      'every time %s, do it %s times' % (said, sn), 'in each of %s rounds %s' % (sn, said),
                      'do %s rounds, each time %s' % (sn, said)])
    return q, 'TIMES %d:%s:END' % (n, code)


def ask(r, held, split):
    lead = ask_lead(r, split)
    kind = r.choice(['op', 'two', 'times', 'count', 'count', 'if', 'if'])
    if held and kind in ('op', 'two'):
        kind = r.choice(['times', 'count', 'if'])
    if split in ('words', 'words1') and kind == 'two':      # that lead has only its trained wordings
        kind = 'op'
    if kind == 'op':
        k = r.randint(2, 12)
        said, expr = r.choice([('print it', 'A'), ('print its double', 'A*2'), ('print its square', 'A*A'),
                               ('print half of it', 'A/2'), ('print it plus %d' % k, 'A+%d' % k),
                               ('print it times %d' % k, 'A*%d' % k), ('print it minus %d' % k, 'A-%d' % k),
                               ('print its cube', 'A*A*A'), ('print three times it', 'A*3')])
        if expr == 'A' or r.random() < 0.8:
            return lead + said, 'INPUT A:OUT ' + expr
        return lead + 'print its times table', 'INPUT A:FOR I=1 TO 10:OUT I*A:NEXT'
    if kind == 'two':
        two = r.choice(['ask for two numbers and ', 'ask me for two numbers then '])
        said, code = r.choice([('print their sum', 'OUT A+B'), ('print their product', 'OUT A*B'),
                               ('print their difference', 'OUT A-B'),
                               ('print the bigger one', 'IF A>B:OUT A:ELSE:OUT B:END'),
                               ('print the smaller one', 'IF A<B:OUT A:ELSE:OUT B:END'),
                               ('count from the first to the second', 'FOR I=A TO B:OUT I:NEXT')])
        return two + said, 'INPUT A:INPUT B:' + code
    if kind == 'times':
        while True:
            a = r.choice(ALL)
            if (a in ASKTIMES_HELD) == held:
                break
        sa, ca = act(r, a)
        return lead + sa + ' that many times', 'INPUT A:TIMES A:%s:END' % ca
    if kind == 'if':
        # a test on the number, with one action, or one action and "otherwise" another
        while True:
            said, op = r.choice(TESTS); a = r.choice(ALL); b = r.choice([None, None] + ALL)
            both = b is not None and b != 'say' and a != 'say'
            if b == a and a != 'say':        # two different texts are a natural pair: say yes ... otherwise say no
                continue
            if held != (both or (b is None and (op, a) in IF_HELD)):
                continue
            break
        k = r.randint(0, 100)
        sa, ca = act(r, a)
        q = lead + ' '.join(('%s if it is %s %d' % (sa, said, k)).split())
        code = 'INPUT A:IF A%s%d:%s' % (op, k, ca)
        if b:
            while True:
                sb, cb = act(r, b)
                if cb != ca:
                    break
            if a == 'say' and b == 'say' and r.random() < 0.4:
                sb = cb.split()[1]             # "say yes if ... otherwise no"
            q += ' otherwise ' + sb; code += ':ELSE:' + cb
        return q, code + ':END'
    while True:
        each = r.choice([None] + EACH); end = r.choice([None] + END)
        if (each is not None and end is not None) == held:
            break
    d = r.choice('ud')
    q = lead + (r.choice(['count to it', 'count up to it']) if d == 'u' else 'count down from it')
    code = 'INPUT A:FOR I=1 TO A' if d == 'u' else 'INPUT A:FOR I=A DOWNTO 1'
    tq, body, after = tail(r, each, end)
    return q + tq, code + ':OUT I' + body + ':NEXT' + after


def other(r, held, split):
    """Shapes with no held-out combination: tables, sums, patterns and loops on keys."""
    k = r.randint(2, 12); sn, n = num(r, 2, 20); b = r.randint(2, 100); a = r.randint(1, 50)
    f = r.randint(2, 8); t = r.choice(SAY); s = r.randint(2, 30); sm, m = num(r, 2, 12)
    return r.choice([
        (r.choice(['print the %d times table', 'show the %d times table']) % k, 'FOR I=1 TO 10:OUT I*%d:NEXT' % k),
        ('print the first %s multiples of %d' % (sn, k), 'FOR I=1 TO %d:OUT I*%d:NEXT' % (n, k)),
        ('print the squares from 1 to %d' % b, 'FOR I=1 TO %d:OUT I*I:NEXT' % b),
        ('print the cubes from 1 to %d' % s, 'FOR I=1 TO %d:OUT I*I*I:NEXT' % s),
        ('print the first %s powers of %d' % (sm, f), 'LET P=1:TIMES %d:LET P=P*%d:OUT P:END' % (m, f)),
        ('add up the numbers from 1 to %d' % b, 'LET S=0:FOR I=1 TO %d:LET S=S+I:NEXT:OUT S' % b),
        ('add up the numbers from %d to %d' % (a, a + b), 'LET S=0:FOR I=%d TO %d:LET S=S+I:NEXT:OUT S' % (a, a + b)),
        ('multiply the numbers from 1 to %d' % f, 'LET P=1:FOR I=1 TO %d:LET P=P*I:NEXT:OUT P' % f),
        ('ask for a number and add up the numbers up to it', 'INPUT A:LET S=0:FOR I=1 TO A:LET S=S+I:NEXT:OUT S'),
        ('print the first %s even numbers' % sn, 'FOR I=1 TO %d:OUT I*2:NEXT' % n),
        ('print the first %s odd numbers' % sn, 'FOR I=1 TO %d:OUT I*2-1:NEXT' % n),
        ('beep higher and higher %s times' % sn, 'FOR I=1 TO %d:BEEP I*100+200 100:NEXT' % n),
        ('beep lower and lower %s times' % sn, 'FOR I=%d DOWNTO 1:BEEP I*100+200 100:NEXT' % n),
        ('play a rising tone', 'FOR I=2 TO 20:BEEP I*100 50:NEXT'),
        ('play a falling tone', 'FOR I=20 DOWNTO 2:BEEP I*100 50:NEXT'),
        ('beep %s times fast' % sn, 'TIMES %d:BEEP 440 100:WAIT 100:END' % n),
        ('beep %s times slowly' % sn, 'TIMES %d:BEEP 440 500:WAIT 500:END' % n),
        (r.choice(['cycle through the colors', 'cycle through the screen colors']), 'FOR I=0 TO 7:COLOR I:WAIT 300:NEXT'),
        ('cycle through the colors %s times' % sn, 'TIMES %d:FOR I=0 TO 7:COLOR I:WAIT 300:NEXT:END' % n),
        ('cycle through the border colors', 'FOR I=0 TO 15:BORDER I:WAIT 300:NEXT'),
        ('cycle through the text colors', 'FOR I=1 TO 15:INK I:WAIT 300:NEXT'),
        ('a timer for %s seconds' % sn, 'FOR I=%d DOWNTO 1:OUT I:WAIT:NEXT:BEEP' % n),
        ('print %s %s times' % (t, sn), 'TIMES %d:ECHO %s:END' % (n, t)),
        ('print a row of %s stars' % sn, 'TIMES %d:PRINT *:END:NL' % n),
        ('print a square of stars %d by %d' % (m, m), 'TIMES %d:TIMES %d:PRINT *:END:NL:END' % (m, m)),
        ('print a triangle of stars with %s lines' % sm, 'FOR I=1 TO %d:TIMES I:PRINT *:END:NL:NEXT' % m),
        ('each time i press a key beep, until q', "FOREVER:KEY:IF K='q':STOP:END:BEEP:END"),
        ('each time i press a key flash, until q', "FOREVER:KEY:IF K='q':STOP:END:FLASH:END"),
        ('each time i press a key say %s, until q' % t, "FOREVER:KEY:IF K='q':STOP:END:ECHO %s:END" % t),
        ('keep asking for a number until it is %d' % b, 'FOREVER:INPUT A:IF A=%d:ECHO yes:STOP:END:ECHO no:END' % b),
    ])


NUMWORDS = {w: i for i, w in enumerate(WORDS) if i >= 2}          # "one" is also a pronoun: the bigger one
PHRASES = ['all done', 'lift off now', 'well done you', 'the end', 'good morning', 'try again', 'that is it', 'here we go']
_NUM = r'(?<![A-Za-z0-9])%s(?![A-Za-z0-9])'


def slot(q):
    """The request with markers for its numbers, and their values.  "two numbers" is not a number of the program."""
    words, values, parts = [], [], q.split(' ')
    for i, w in enumerate(parts):
        v = int(w) if w.isdigit() else NUMWORDS.get(w)
        if v is not None and v < 2:           # 0 and 1 stay: programs are full of their own ("FOR I=1", "LET P=1")
            v = None
        if v is None or parts[i + 1:i + 2] == ['numbers']:
            words.append(w)
        else:
            values.append(v); words.append('n%d' % len(values))
    return ' '.join(words), values


def slotted(r, q, a, texts=0.5):
    """(request, answer, numbers, texts) as the expert sees them; None if a number of the request is also a
    fixed number of the answer, so that no rule could tell which is which."""
    q2, values = slot(q)
    left = list(values)

    def mark(m):
        v = int(m.group())
        if v in left:
            k = left.index(v); left[k] = None
            return 'n%d' % (k + 1)
        return m.group()
    a2 = re.sub(_NUM % r'\d+', mark, a)
    for v in set(values):
        if len(re.findall(_NUM % v, a)) > values.count(v):
            return None
    said = [m for m in re.findall(r'(?:ECHO|PRINT) ([a-z]+)', a) if m in q2.split(' ')]
    order = []
    if said and r.random() < texts:
        order = sorted(set(said), key=q2.split(' ').index)
        for k, t in enumerate(order, 1):
            q2 = ' '.join('t%d' % k if w == t else w for w in q2.split(' '))
            a2 = re.sub(r'(ECHO|PRINT) %s(?![a-z])' % t, r'\1 t%d' % k, a2)
    return q2, a2, values, order


def fill(q2, a2, numbers, texts, quote):
    """Put values back in place of the markers."""
    for k in range(len(numbers), 0, -1):
        q2 = q2.replace('n%d' % k, str(numbers[k - 1])); a2 = a2.replace('n%d' % k, str(numbers[k - 1]))
    for k in range(len(texts), 0, -1):
        q2 = q2.replace('t%d' % k, quote % texts[k - 1]); a2 = a2.replace('t%d' % k, texts[k - 1])
    return q2, a2


def fits(q, a):
    return len(q) <= 72 and len(q) + len(a) <= LIMIT


def make(r, split='seen', slots=False):
    """One (request, program) of the given split.  With slots, the pair as the expert sees it."""
    if split in ('far', 'quoted'):
        while True:
            got = slotted(r, *make(r, 'seen'), texts=1.0)
            if got is None:
                continue
            q2, a2, numbers, texts = got
            if not (numbers if split == 'far' else texts):
                continue
            if split == 'far':                    # big numbers in the same order of size
                big = sorted(r.sample(range(150, 10000), len(set(numbers))))
                numbers = [big[sorted(set(numbers)).index(v)] for v in numbers]
                q, a = fill(q2, a2, numbers, texts, '%s')
            else:
                q, a = fill(q2, a2, numbers, r.sample(PHRASES, len(texts)), '"%s"')
            if fits(q, a) and fits(q2, a2):
                return (q2, a2) if slots else (q, a)
    if slots:
        while True:
            got = slotted(r, *make(r, split))
            if got and fits(*got[:2]):
                return got[:2]
    held = split == 'combo'
    fams = [count, count, times, ask, ask]
    if split == 'seen':
        fams += [other, other]
    while True:
        q, a = r.choice(fams)(r, held, split)
        if len(q) <= 72 and len(q) + len(a) <= LIMIT:
            return q, a


if __name__ == '__main__':
    args = sys.argv[1:]
    r = random.Random(int(args[args.index('--seed') + 1]) if '--seed' in args else 1)
    split = args[1] if len(args) > 1 and not args[1].startswith('--') else 'seen'
    for _ in range(int(args[0])):
        q, a = make(r, split)
        print(json.dumps(dict(question=q, answer=a)))
