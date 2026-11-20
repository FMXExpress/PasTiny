#!/usr/bin/env python3
"""Label training questions with a local OpenJev server (the teacher).

  python3 build_distill.py MINUTES OUT.jsonl [--url http://127.0.0.1:8081] [--model laya-1.0]
                           [--banking banking77.parquet] [--bitext bitext.csv] [--seed 1]

Start the teacher first, in the OpenJev checkout:
  OPENJEV_BACKEND=laya OPENJEV_DEVICE=cpu OPENJEV_PORT=8081 python -m openjev

States come from three places: the template generator (gen_jev.py), PolyAI's
banking77 and Bitext's customer-support set (both optional; pandas is needed to
read them).  Every state gets several typed questions drawn from a wide pool,
and the teacher's probabilities are stored as the labels.  The teacher sees the
same cleaned text the DOS program will see.  Lines are appended, so a run can be
stopped and continued.

One record per line:
  {"state", "type", "instructions", "options": [...] or null,
   "p": P(yes) or [probability per option], "src", "held": true for test states}
"""
import hashlib
import json
import random
import re
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_jev
from gen_jev import TOPICS, TONE_WORDS, URG_WORDS, _split, fit_state, fit_text

PER_STATE = 8          # questions asked about each state, in one request

# ------------------------------------------------------------------ questions
ADJ = ['upset', 'angry', 'happy', 'calm', 'confused', 'polite', 'rude', 'worried', 'in a hurry', 'satisfied',
       'frustrated', 'annoyed', 'pleased', 'impatient', 'furious', 'unhappy', 'grateful', 'disappointed',
       'relaxed', 'stressed', 'friendly', 'hostile', 'desperate', 'curious']
WHO = ['the customer', 'the user', 'the writer', 'the sender', 'this person']
IS_THIS = ['urgent', 'spam', 'a complaint', 'a question', 'a request', 'praise', 'a threat', 'a bug report',
           'a refund request', 'about money', 'about a card', 'about a password', 'about delivery',
           'about an order', 'about an account', 'about a payment', 'about fees', 'about a transfer',
           'about cancelling', 'about a subscription', 'about login', 'about an invoice', 'about a refund',
           'about shipping', 'about a broken service', 'about a new feature', 'about security', 'about fraud',
           'about personal details', 'about an app', 'about a website', 'feedback', 'a thank you note',
           'an advertisement', 'a scam', 'a how-to question', 'a technical problem', 'a billing problem',
           'time sensitive', 'low priority', 'high priority', 'a serious problem', 'a minor issue',
           'good news', 'bad news', 'written in anger', 'a first contact', 'a repeated problem']
DOES = ['ask a question', 'want a refund', 'want to cancel', 'need help now', 'mention a deadline',
        'mention money', 'report a problem', 'thank us', 'threaten to leave', 'want a human',
        'ask for instructions', 'complain', 'ask about a price', 'want to change something',
        'want to buy something', 'report an error', 'ask for a status update', 'mention a card',
        'mention an order', 'mention a date or time', 'sound angry', 'sound happy', 'need a fast reply',
        'want their money back', 'have a technical problem', 'ask how to do something',
        'want to close the account', 'say something positive', 'say something negative', 'use strong words']
SHOULD = ['reply right away', 'escalate this', 'ignore this', 'apologise', 'refund the customer',
          'call the customer', 'send instructions', 'treat this as urgent', 'answer within the hour',
          'pass this to a manager', 'mark this as spam', 'thank the customer']

LABELS = ['billing', 'refund', 'payment', 'card', 'account', 'login', 'password', 'delivery', 'order',
          'shipping', 'cancel', 'subscription', 'feedback', 'complaint', 'praise', 'spam', 'outage', 'bug',
          'feature request', 'question', 'transfer', 'fees', 'security', 'fraud', 'invoice', 'contact',
          'other', 'technical problem', 'how-to', 'pricing', 'returns', 'address change', 'newsletter',
          'identity check', 'exchange rate', 'cash withdrawal', 'top up', 'pin', 'lost card', 'limits',
          'sales', 'support', 'general question', 'account access', 'money', 'orders', 'product ideas']
CHOICE_INSTR = _split(gen_jev.TOPIC_CHOICE, False) + [
    'what does the customer want', 'best label', 'main subject', 'classify this message', 'intent',
    'which queue', 'who handles this', 'what is the problem', 'subject', 'kind of request']
SCALES = [
    (_split(gen_jev.TONE_CHOICE, False) + ['how unhappy is the customer', 'anger level'],
     [[_split(w, False) for w in TONE_WORDS],
      [['not at all'], ['somewhat', 'a little'], ['very', 'extremely']],
      [['happy', 'pleased'], ['neutral', 'ok'], ['angry', 'upset']],
      [['low'], ['medium'], ['high']]]),
    (_split(gen_jev.URG_CHOICE, False) + ['how quickly do we need to act', 'time pressure'],
     [[_split(w, False) for w in URG_WORDS],
      [['can wait'], ['soon', 'today'], ['now', 'immediately']],
      [['low'], ['medium'], ['high']]]),
    (['how satisfied is the customer', 'satisfaction', 'how happy is the customer'],
     [[['very unhappy'], ['unhappy'], ['neutral'], ['happy'], ['very happy']],
      [['unhappy', 'dissatisfied'], ['neutral', 'ok'], ['happy', 'satisfied']],
      [['low'], ['medium'], ['high']]]),
    (['how polite is the message', 'politeness'],
     [[['rude'], ['neutral'], ['polite']], [['low'], ['medium'], ['high']]]),
    (['how serious is the problem', 'severity', 'how bad is it'],
     [[['no problem', 'minor'], ['moderate', 'annoying'], ['serious', 'critical']],
      [['low'], ['medium'], ['high']]]),
]


def make_questions(rng, hint):
    """PER_STATE questions for one state.  `hint` is a label that probably
    fits it (or None); it is offered as one option of some choices."""
    out = []
    while len(out) < PER_STATE:
        r = rng.random()
        if r < 0.45:
            form = rng.random()
            if form < 0.15:
                words, _ = rng.choice(gen_jev.NOULS)
                instr = rng.choice(_split(words, False))
            elif form < 0.40:
                instr = 'is %s %s' % (rng.choice(WHO), rng.choice(ADJ))
            elif form < 0.70:
                x = rng.choice(IS_THIS) if not hint or rng.random() < 0.7 else 'about ' + hint
                instr = rng.choice(['is this %s', 'is it %s', 'is the message %s']) % x
            elif form < 0.90:
                instr = 'does %s %s' % (rng.choice(WHO), rng.choice(DOES))
            else:
                instr = 'should we ' + rng.choice(SHOULD)
            out.append(dict(type='noul', instructions=instr, options=None))
        elif r < 0.80:
            k = rng.randint(2, 6)
            pool = LABELS + [w for t in TOPICS for w in _split(TOPICS[t][0], False)]
            opts = rng.sample(pool, k)
            if hint and rng.random() < 0.65:
                opts[rng.randrange(k)] = hint
            if len(set(opts)) == k:
                out.append(dict(type='choice', instructions=rng.choice(CHOICE_INSTR), options=opts))
        else:
            instrs, sets = rng.choice(SCALES)
            levels = [rng.choice(w) for w in rng.choice(sets)]
            out.append(dict(type='score', instructions=rng.choice(instrs), options=levels))
    return out


# ------------------------------------------------------------------ states
def held_out(text):
    """One real message in ten is kept for testing, chosen by its text."""
    return hashlib.sha1(text.encode()).digest()[0] < 26


def load_real(banking, bitext, rng):
    """[(state, source, hint)] from the public datasets that are present."""
    rows = []
    try:
        import pandas as pd
    except ImportError:
        return rows
    if banking and Path(banking).exists():
        for text in pd.read_parquet(banking)['text']:
            rows.append((fit_state(text), 'banking77', None))
    if bitext and Path(bitext).exists():
        df = pd.read_csv(bitext)
        for text, cat, intent in zip(df['instruction'], df['category'], df['intent']):
            text = re.sub(r'\{\{[^}]*\}\}', lambda m: str(rng.randint(1000, 99999)), str(text))
            hint = rng.choice([str(cat).lower().replace('_', ' '), str(intent).replace('_', ' ')])
            rows.append((fit_state(text), 'bitext', hint if len(hint) <= 24 else None))
    rows = [r for r in rows if 12 <= len(r[0]) <= gen_jev.STATEMAX]
    rng.shuffle(rows)
    return rows


def ask(url, model, state, questions):
    body = {'model': model, 'state': state, 'questions': {}}
    for i, q in enumerate(questions):
        item = {'type': q['type'], 'instructions': q['instructions']}
        if q['type'] == 'choice':
            item['criteria'] = {o: None for o in q['options']}
        elif q['type'] == 'score':
            item['criteria'] = q['options']
        body['questions']['q%d' % i] = item
    req = urllib.request.Request(url + '/v1/systemone', json.dumps(body).encode(),
                                 {'Content-Type': 'application/json'})
    answers = json.loads(urllib.request.urlopen(req, timeout=600).read())['answers']
    out = []
    for i, q in enumerate(questions):
        a = answers['q%d' % i]
        if q['type'] == 'noul':
            out.append(round(a['noul'], 4))
        else:
            p = a['probabilities']
            keys = q['options'] if q['type'] == 'choice' else [str(j) for j in range(len(q['options']))]
            out.append([round(p[k], 4) for k in keys])
    return out


def main():
    args = sys.argv[1:]
    opt = {args[i][2:]: args[i + 1] for i in range(len(args) - 1) if args[i].startswith('--')}
    minutes, out = float(args[0]), Path(args[1])
    url, model = opt.get('url', 'http://127.0.0.1:8081'), opt.get('model', 'laya-1.0')
    rng = random.Random(int(opt.get('seed', 1)))
    real = load_real(opt.get('banking'), opt.get('bitext'), rng)
    print('real states', len(real), flush=True)
    t0, n = time.time(), 0
    with out.open('a') as f:
        while time.time() - t0 < minutes * 60:
            if real and rng.random() < 0.6:
                state, src, hint = real.pop()
                held = held_out(state)
            else:
                st = gen_jev.make_state(rng, held=False)
                state, src, held = st.text, 'template', False
                hint = rng.choice(_split(TOPICS[st.topic][0], False))
            qs = [q for q in make_questions(rng, hint)
                  if len(state) + 1 + len(fit_text(q['instructions']))
                  + (1 + max(len(fit_text(o)) for o in q['options']) if q['options'] else 0) <= gen_jev.MAXLEN]
            if not qs:
                continue
            for q, p in zip(qs, ask(url, model, state, qs)):
                f.write(json.dumps(dict(state=state, type=q['type'], instructions=q['instructions'],
                                        options=q['options'], p=p, src=src, held=held)) + '\n')
                n += 1
            f.flush()
            if n % 800 < len(qs):
                print('%6d questions %5.0fs' % (n, time.time() - t0), flush=True)
    print('done', n, flush=True)


if __name__ == '__main__':
    main()
