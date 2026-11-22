"""Expand the original training splits with varied names and positions for each term."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
groups = {
    'FATVOL': ('batch80/007', [
        ['cluster', 'fat cluster', 'fat12 cluster', 'allocation unit'],
        ['root directory', 'root', 'fat16 root directory', 'fat root'],
        ['file allocation table', 'fat table', 'allocation table', 'fat chain table'],
        ['volume label', 'label', 'disk label', 'fat label']]),
    'BOOLLOG': ('batch100/030', [
        ['and', 'conjunction', 'and gate', 'logical and'],
        ['or', 'disjunction', 'inclusive or', 'logical or'],
        ['xor', 'exclusive or', 'xor gate', 'exclusive disjunction'],
        ['not', 'negation', 'inverter', 'logical not']]),
    'TERMINAL': ('batch70/038', [
        ['sysop', 'system operator', 'bbs sysop'],
        ['handle', 'user handle', 'bbs handle'],
        ['door', 'door game', 'bbs door'],
        ['netmail', 'fidonet netmail', 'netmail message'],
        ['echomail', 'fidonet echomail', 'echomail message'],
        ['ansi art', 'ansi', 'ansi graphics']]),
}
templates = [
    '{}', '{} means what', 'tell me about {} please', 'what exactly is {}',
    'can you describe {} simply', 'explain the term {} to me',
    'how does {} work here', 'what is the job of {}',
    'in this context what does {} refer to', 'what does a {} represent',
    'how would you define {}', '{} in a few words please',
    'when people mention {} what do they mean', 'help me understand {}',
    'give me a quick summary of {}', 'i need a definition for {}',
]

def read(path):
    return [json.loads(line) for line in path.read_text().splitlines()]

def corpus(name):
    folder, aliases = groups[name]
    source = root.parents[1] / folder
    rows = read(source / 'train.jsonl')
    reserved = {r['question'].casefold() for r in read(source / 'heldout.jsonl')}
    by_question = {r['question']: r['answer'] for r in rows}
    for answer, terms in zip(dict.fromkeys(by_question.values()), aliases, strict=True):
        for term in terms:
            for template in templates:
                q = template.format(term)
                if q not in reserved:
                    by_question[q] = answer
    assert reserved.isdisjoint(q.casefold() for q in by_question)
    return [dict(question=q, answer=a) for q, a in by_question.items()]

if __name__ == '__main__':
    import sys
    for row in corpus(sys.argv[1]):
        print(json.dumps(row))
