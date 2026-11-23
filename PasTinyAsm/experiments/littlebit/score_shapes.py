"""Diagnostic ceiling for number and literal binding with program structure held fixed."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import subprocess
import sys

from score_experts import probes, signed_crc


def shape(command):
    statements = []
    for statement in command.split(':'):
        op, _, argument = statement.partition(' ')
        if op == 'NL':
            op = 'NEWLINE'
        if op in ('PRINT', 'ECHO') and argument:
            statements.append(op + ' <text>')
        else:
            statements.append(re.sub(r'\d+', '#', op + (' ' + argument if argument else '')))
    return ':'.join(statements)


def run(executable, directory, expert):
    model = (directory / (expert + '.T16')).resolve()
    rows = list(probes(expert))
    result = subprocess.run([executable.resolve(), model, str(signed_crc(model))],
                            input=''.join(q+'\n' for q, _ in rows), text=True,
                            capture_output=True, check=True)
    exact = compatible = 0
    for actual, (_, target) in zip(result.stdout.splitlines(), rows, strict=True):
        exact += actual == target
        compatible += shape(actual) == shape(target)
    return expert, exact, compatible


if __name__ == '__main__':
    executable, directory = map(Path, sys.argv[1:])
    experts = ('screen', 'text', 'tasks', 'recipes', 'slots')
    with ThreadPoolExecutor(max_workers=2) as pool:
        for expert, exact, compatible in pool.map(lambda e: run(executable, directory, e), experts):
            print(f'{expert}: exact {exact}/300, same shape {compatible}/300', flush=True)
