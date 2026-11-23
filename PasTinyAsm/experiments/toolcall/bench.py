"""Build a sound/text selector corpus and score exported Tiny weights in Pascal."""
import argparse
import collections
import json
from pathlib import Path
import random
import re
import time
import subprocess
import sys
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'training'))
import gen_asm

LABELS = dict(zip('BEEP SIREN WAIT SCALE KEY REPEAT PRINT NUMBER NEWLINE'.split(), 'ABCDEFGHI'))
LABELS['NL'] = LABELS['NEWLINE']


ASK = 'J'
NEGATIVE_PATTERNS = (
    'explain how {} works', 'what does {} mean', 'where can i find {}',
    'tell me about {}', 'can you describe {}', 'i need information about {}',
    'do something with {}', 'what should i do about {}',
    'why is {} important', 'how do people use {}',
)
NEGATIVE_TOPICS = (
    'a siren', 'the speaker', 'a tone', 'the printer', 'a number', 'the text',
    'a delay', 'a tune', 'a file', 'the display', 'the keyboard', 'the disk',
    'a map', 'a spreadsheet', 'the moon', 'a recipe', 'the program',
)
PROBES = (
    'list files in this directory', 'how much memory is free',
    'what is the capital of peru', 'draw a blue rectangle', 'rename this file',
    'create a room with a lamp', 'what time is it', 'explain what a siren does',
    'how long does the tone last', 'make it louder', 'do the same thing',
    'which number should i show', 'is it possible to print a file',
    'why did the alarm sound', 'what would happen if i press a key',
    'read my project notes', 'find the word beep in this file',
    'does this computer have a speaker', 'show me how a siren works',
    'is waiting for a key the same as a delay',
)

def negatives():
    for pattern in NEGATIVE_PATTERNS:
        for topic in NEGATIVE_TOPICS:
            yield pattern.format(topic)


def pairs(seed, count, held):
    rng = random.Random(seed)
    for family in ('sound', 'text'):
        for _ in range(count):
            q, answer = gen_asm.make(rng, family, held=held)
            yield family, q, answer


def preview_text(question, label):
    """Preview only the text forms whose argument boundaries we can verify."""
    if label == LABELS['NUMBER']:
        match = re.fullmatch(r'(?:print out|show me) the number ([0-9]+)', question)
        if match and int(match[1]) <= 65535:
            return 'NUMBER ' + str(int(match[1]))
    if label == LABELS['PRINT']:
        match = re.fullmatch(r'(?:print out|show me|display the phrase|write the sentence) ([a-z0-9 ]{1,60})', question)
        if match and not match[1].startswith('the number '):
            return 'PRINT ' + match[1]
    if label == LABELS['NEWLINE'] and question in ('start another line', 'jump to the next line', 'one line down'):
        return 'NEWLINE'
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--score', nargs=2, metavar=('CHECK', 'BIN'), type=Path)
    parser.add_argument('--editor', type=Path)
    parser.add_argument('--ask', action='store_true')
    args = parser.parse_args()
    if args.score is None and args.editor is None:
        for _, q, command in pairs(11, 4000, False):
            print(json.dumps(dict(question=q, answer=LABELS[command.split()[0]])))
        if args.ask:
            for q in negatives():
                for _ in range(6):
                    print(json.dumps(dict(question=q, answer=ASK)))
        return
    training = {q for _, q, _ in pairs(11, 4000, False)}
    rows = [row for row in pairs(935, 300, True) if row[1] not in training and ' and ' not in f' {row[1]} ']
    if args.ask:
        assert set(PROBES).isdisjoint(negatives())
        rows.extend(('clarification', q, ASK) for q in PROBES)
    started = time.monotonic()
    full_answers = []
    if args.editor:
        exe = args.editor.resolve()
        result = subprocess.run([exe], cwd=exe.parent, check=True, text=True,
                                input=''.join(f'new\n{q}\n' for _, q, _ in rows)+'quit\n',
                                capture_output=True)
        answers = []
        for block in result.stdout.split('> new\n')[1:]:
            line = re.search(r'^1 .*? -> (.+?)(?:\s+\((?:no model|second choice)\))?$', block, re.M)
            full_answers.append(line[1] if line else None)
            answers.append(LABELS.get(line[1].split()[0], '?') if line else '?')
    else:
        exe, weights = args.score
        crc = zlib.crc32(weights.read_bytes())
        if crc >= 2**31:
            crc -= 2**32
        result = subprocess.run([exe.resolve(), weights.resolve(), str(crc)], check=True, text=True,
                                input=''.join(q+'\n' for _, q, _ in rows), capture_output=True)
        answers = result.stdout.splitlines()
        full_answers = [preview_text(q, a) if f == 'text' else None
                        for (f, q, _), a in zip(rows, answers, strict=True)]
    print(f'Batch elapsed {time.monotonic()-started:.2f}s')
    totals = collections.Counter()
    correct = collections.Counter()
    invalid = collections.Counter()
    declined = collections.Counter()
    text = collections.Counter()
    for (family, _, command), answer, full in zip(rows, answers, full_answers, strict=True):
        expected = ASK if family == 'clarification' else LABELS[command.split()[0]]
        if family == 'text':
            text['exact' if full == command else 'clarify' if full is None else 'wrong'] += 1
        totals[family] += 1
        correct[family] += expected == answer
        invalid[family] += answer not in (*LABELS.values(), ASK)
        declined[family] += answer == ASK
    print('Text complete calls:', dict(text))
    if not args.editor:
        rules = collections.Counter()
        for family, q, expected in rows:
            if family != 'text':
                continue
            candidates = [preview_text(q, code) for code in set(LABELS.values())]
            matches = [candidate for candidate in candidates if candidate is not None]
            full = matches[0] if len(matches) == 1 else None
            rules['exact' if full == expected else 'clarify' if full is None else 'wrong'] += 1
        print('Text rules alone:', dict(rules))
    for family in totals:
        print(f'{family}: {correct[family]}/{totals[family]}, ASK {declined[family]}, invalid outputs {invalid[family]}')


if __name__ == '__main__':
    main()
