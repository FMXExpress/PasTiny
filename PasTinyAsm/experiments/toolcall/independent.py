"""Compare the old preview with an explicit-command preview on hand-written cases."""
from collections import Counter
from pathlib import Path
import re

from bench import LABELS, preview_text


def old_preview(question):
    candidates = [preview_text(question, label) for label in set(LABELS.values())]
    matches = [candidate for candidate in candidates if candidate is not None]
    return matches[0] if len(matches) == 1 else 'ASK'


def explicit_preview(question):
    # Quoted payloads are literal. Return a preview value, never executable source.
    literal = re.fullmatch(r'(?:print(?: out)?|say|display|write|show me) "([ -!#-~]{1,60})"',
                           question, re.IGNORECASE)
    if literal:
        return 'PRINT ' + literal[1]
    number = re.fullmatch(r'(?:print out|show me) the number ([0-9]{1,5})', question)
    if number and int(number[1]) <= 65535:
        return 'NUMBER ' + str(int(number[1]))
    if question in ('start another line', 'jump to the next line', 'one line down'):
        return 'NEWLINE'
    return 'ASK'


def main():
    rows = [line.split('\t', 1) for line in Path(__file__).with_suffix('.tsv').read_text().splitlines()]
    for preview in (old_preview, explicit_preview):
        counts = Counter()
        for question, target in rows:
            target = target.replace(r'\x20', ' ')
            answer = preview(question)
            if target == 'ASK':
                category = 'correct ASK' if answer == target else 'wrong call'
            elif answer == 'ASK':
                category = 'clarified supported'
            else:
                category = 'exact call' if answer == target else 'wrong call'
            counts[category] += 1
        print(preview.__name__, dict(counts))


if __name__ == '__main__':
    main()
