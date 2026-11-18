"""Drive a JEV executable from Python: API-style questions in, answer dicts out."""
import re
import subprocess
import threading


def tidy(text):
    text = ''.join(c if ' ' <= c <= '~' else ' ' for c in str(text).lower()).replace('|', '/')
    return re.sub(r' +', ' ', text).strip()


class TooLong(ValueError):
    pass


def command(tag, q):
    """The JEV command line for one question, and the names of its options."""
    kind = q['type']
    instr = tidy(q.get('instructions') or 'answer about the state')
    crit = q.get('criteria')
    if kind == 'noul':
        return 'NOUL %s | %s' % (tag, instr), None
    if kind == 'choice':
        names = list(crit)
        return 'CHOICE %s | %s | ' % (tag, instr) + ' ; '.join(
            '%d=%s' % (i, tidy(crit[k] or k).replace(';', ',')) for i, k in enumerate(names)), names
    if kind == 'score':
        return ('SCORE %s | %s | ' % (tag, instr) + ' ; '.join(tidy(c).replace(';', ',') for c in crit),
                [str(i) for i in range(len(crit))])
    raise ValueError('unknown question type')


def script(questions):
    """Command lines that ask a list of {state, type, instructions, criteria}."""
    lines, state = [], None
    for n, q in enumerate(questions):
        text = tidy(q['state'])
        if text != state:
            lines.append('STATE ' + text)
            state = text
        lines.append(command('q%d' % n, q)[0])
    return lines


class Runtime:
    """One JEV process, kept running.  `cwd` holds EXPERTS.CAT and the models."""

    def __init__(self, exe, cwd):
        self.lock = threading.Lock()
        self.proc = subprocess.Popen([str(exe)], cwd=str(cwd), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     text=True, bufsize=1)
        self.state = None
        self.banner = self._until('active ', 'unloaded')

    def _until(self, *starts):
        lines = []
        while True:
            line = self.proc.stdout.readline()
            if not line:
                raise RuntimeError('JEV stopped: ' + ' / '.join(lines))
            lines.append(line.rstrip('\n'))
            if line.startswith(starts):
                return lines

    def _send(self, line):
        if len(line) > 255 or '\n' in line:
            raise TooLong('a request line is limited to 255 letters')
        self.proc.stdin.write(line + '\n')
        self.proc.stdin.flush()

    def decide(self, state, questions):
        """questions: {id: {type, instructions, criteria}} -> ({id: answer}, letters read)"""
        answers, letters = {}, 0
        with self.lock:
            text = tidy(state)
            if len(text) > 200:                       # the runtime keeps 53 + 26 letters anyway
                text = text[:100] + ' ' + text[-99:]
            if text != self.state:
                self._send('STATE ' + text)
                self._until('state chars=')
                self.state = text
                letters += min(len(text), 80)
            for n, (qid, q) in enumerate(questions.items()):
                kind, tag, crit = q['type'], 'q%d' % n, q.get('criteria')
                line, names = command(tag, q)
                self._send(line)
                out = self._until(tag + ' ')[-1].split(' ')
                fields = dict(f.split('=', 1) for f in out[1:] if '=' in f)
                if 'error' in fields:
                    raise TooLong(' '.join(out[1:])[6:])
                letters += len(line)
                if kind == 'noul':
                    answers[qid] = {'type': 'noul', 'noul': float(fields['noul'])}
                    continue
                probs = {name: float(fields[str(i)]) for i, name in enumerate(names)}
                a = {'type': kind}
                if kind == 'choice':
                    a['choice'] = names[int(fields['choice'])]
                else:
                    a['score'] = float(fields['score'])
                    a['legend'] = {str(i): c for i, c in enumerate(crit)}
                a['probabilities'] = probs
                a['confidence'] = float(fields['confidence'])
                answers[qid] = a
        return answers, letters

    def close(self):
        try:
            self.proc.stdin.write('QUIT\n')
            self.proc.stdin.flush()
            self.proc.wait(timeout=5)
        except Exception:
            self.proc.kill()
