"""Host experiments producing ordinary MAKECOM source and a DOS world table."""
from pathlib import Path
from itertools import product
import argparse

def edit(lines, request):
    if not lines:
        raise ValueError('Select a line first')
    if request == 'do that twice':
        return lines + [lines[-1]]
    if request == 'the same but red':
        op = lines[-1].split()[0]
        if op in ('INK', 'COLOR', 'BORDER'):
            return lines + [op + ' 4']
    if request == 'make it louder':
        raise ValueError('BEEP has pitch and duration only')
    raise ValueError('Which operation should change?')

def synth(examples):
    # Word arithmetic. Enumerate one operator before trying a second.
    ops = [(symbol,k) for symbol in ('+','-','*') for k in range(1,10)]
    for depth in range(3):
        for program in product(ops, repeat=depth):
            def run(x):
                for op,k in program:
                    x = {'+': x+k, '-': x-k, '*': x*k}[op] % 65536
                return x
            if all(run(x)==y for x,y in examples):
                return program,run
    raise ValueError('No match in grammar')

def prepare(dest):
    lines=edit(edit(['COLOR 1'],'the same but red'),'do that twice')
    assert lines==['COLOR 1','COLOR 4','COLOR 4']
    for state,request in [([], 'do that twice'),(['BEEP 440 300'],'make it louder'),
                          (['KEY'],'the same but red')]:
        try: edit(state,request)
        except ValueError: pass
        else: raise AssertionError(request)
    (dest/'EDIT.SRC').write_bytes(('\r\n'.join(lines)+'\r\n').encode())
    for i,fn in enumerate([lambda x:x*2,lambda x:x+7,lambda x:3*x+2]):
        program,run=synth([(x,fn(x)) for x in (1,3,7)])
        assert all(run(x)==fn(x)%65536 for x in range(51))
        src=['INPUT A']+[f'LET A=A{op}{k}' for op,k in program]+['OUT A']
        (dest/f'P{i}.SRC').write_bytes(('\r\n'.join(src)+'\r\n').encode())
        print(src)
    assert synth([(1,2)])[1](3)!=6  # one example also fits x+1
    n=50
    (dest/'rooms.inc').write_text('rooms:\n'+''.join(
        f'.byte {i+1 if i<n-1 else 255},{i-1 if i else 255}\n.word name{i}\n' for i in range(n))
        +''.join(f'name{i}: .ascii "Room {i+1}\\r\\n$"\n' for i in range(n)))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    prepare(parser.parse_args().directory)
