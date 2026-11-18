"""Host checks for PasTinyJev.

  python3 tests/test_host.py INT_JEV FLOAT_JEV

INT_JEV and FLOAT_JEV are native builds (fpc -Mtp JEV.PAS, and with
-dFLOATMATH).  Checks the command protocol, state caching, model switching and
recovery, and that both engines give the probabilities PyTorch gives for the
exported model on every hand-written question.
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'training'))
import package
from jevrun import Runtime
import train_jev

exes = [Path(p).resolve() for p in sys.argv[1:3]]


def run(exe, cwd, text):
    out = subprocess.run([exe], input=text, text=True, capture_output=True, cwd=cwd)
    return out.returncode, [' '.join(f for f in s.split(' ') if not f.startswith('ms=')) for s in out.stdout.splitlines()]


with tempfile.TemporaryDirectory() as tmp:
    rt = Path(tmp) / 'rt'
    package.build(json.loads((ROOT / 'models.json').read_text()), exes[0], rt, 'JEV')
    exe = rt / 'JEV'

    # protocol and errors
    S = 'STATE i was charged twice this month\n'
    code, out = run(exe, rt, S + 'NOUL a | is this a billing issue\nNOUL b |\nCHOICE c | topic\n'
                    'NOUL d | ' + 'x' * 120 + '\nBOGUS\nUSE 9\nQUIT\nNOUL never | runs\n')
    assert code == 0 and out[2] == 'state chars=30' and out[3].startswith('a noul='), out
    assert out[4:] == ['b error=no instructions', 'c error=no options', 'd error=too long by 24',
                       'error=unknown command bogus', 'unknown id'], out
    code, out = run(exe, rt, 'NOUL a | is this spam\n')
    assert out[-1] == 'a error=no state', out

    # a long state keeps its head and tail; text is tidied
    code, out = run(exe, rt, 'STATE ' + 'Ab|  ' * 40 + '\n')
    assert out[-1] == 'state chars=80', out

    # the cached state gives the same answer as a fresh one, also after ASK and USE
    ask = 'NOUL a | is this a billing issue\n'
    cho = 'CHOICE c | topic | billing=money ; shipping=parcels ; spam=junk\n'
    first = run(exe, rt, S + ask + cho)[1][-2:]
    again = run(exe, rt, S + cho + ask + cho + 'ASK what is 7 times 8\n' + ask + cho)[1]
    assert again[-2:] == first and again[4:6] == first and '7 times 8 is 56.' in again, again
    assert 'active 2 TINY 2.1 general answers' in again and again[-3].startswith('active 1 '), again
    pinned = run(exe, rt, S + 'USE 2\n' + ask + 'AUTO\n' + ask)[1]
    assert pinned[-1] == first[0] and pinned[-3] != first[0], pinned

    # the word "ask" in a decision must not send it to the text model
    out = run(exe, rt, S + 'NOUL a | does the customer ask a question\n')[1]
    assert not any(s.startswith('active 2') for s in out) and out[-1].startswith('a noul='), out

    # a damaged model is refused and the previous one comes back
    good = (rt / 'GENERAL.BIN').read_bytes()
    (rt / 'GENERAL.BIN').write_bytes(good[:-1] + bytes([good[-1] ^ 1]))
    out = run(exe, rt, S + 'USE 2\n' + ask)[1]
    assert 'load failed GENERAL.BIN CRC32 mismatch' in out and out[-1] == first[0], out
    (rt / 'GENERAL.BIN').write_bytes(good)
    catalog = (rt / 'EXPERTS.CAT').read_bytes()
    (rt / 'EXPERTS.CAT').write_bytes(b'FAIL' + catalog[4:])
    assert run(exe, rt, 'QUIT\n')[0] == 1
    (rt / 'EXPERTS.CAT').write_bytes(catalog)

    # both engines against PyTorch on the hand-written questions
    model = train_jev.load(ROOT / 'JEV.BIN').eval()
    qs = [json.loads(s) for s in (ROOT / 'training/wild.jsonl').read_text().splitlines() if s.strip()]
    for name, path in zip(('integer', 'float'), exes):
        shutil.copy(path, exe)
        runtime = Runtime(exe, rt)
        worst, right, flips = 0.0, 0, 0
        for q in qs:
            ref = train_jev.answer(model, q)
            got = runtime.decide(q['state'], {'q': q})[0]['q']
            if q['type'] == 'noul':
                worst = max(worst, abs(got['noul'] - ref['noul']))
            else:
                worst = max(worst, max(abs(got['probabilities'][k] - ref['probabilities'][str(k)])
                                       for k in got['probabilities']))
                got['probabilities'] = {str(k): v for k, v in got['probabilities'].items()}
            right += train_jev.judge(q, got)
            flips += train_jev.judge(q, got) != train_jev.judge(q, ref)
        runtime.close()
        print('%s engine: %d/%d hand-written questions, largest probability gap to PyTorch %.4f, '
              '%d decisions differ' % (name, right, len(qs), worst, flips))
        assert worst < 0.02 and flips == 0, (worst, flips)
print('Host: protocol, caching, switching, recovery and PyTorch parity passed.')
