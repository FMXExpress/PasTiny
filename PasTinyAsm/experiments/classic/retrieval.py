"""Nearest-example SOUND translator; use only examples from the training generator."""
from pathlib import Path
import random
import sys

root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'training'))
import gen_asm

def features(q):
    words=q.split()
    values=[]
    for i,w in enumerate(words):
        if w.isdecimal() or w in gen_asm.WORDS or w=='half':
            v=int(w) if w.isdecimal() else 0.5 if w=='half' else gen_asm.WORDS.index(w)
            unit=words[i+1:i+2]
            if unit in (['second'],['seconds']) or (w=='half' and words[i+1:i+3]==['a','second']):
                v*=1000
            values.append(int(v))
            words[i]='N'+str(len(values))
    return set(words),values

def train():
    rng=random.Random(11)
    table={}
    for _ in range(4000):
        q,a=gen_asm.make(rng,'sound')
        words,values=features(q)
        tokens=a.split()
        for i,t in enumerate(tokens):
            if t.isdecimal() and int(t) in values:
                tokens[i]='@'+str(values.index(int(t)))
        table.setdefault((frozenset(words),tuple(tokens)),None)
    return list(table)

def predict(q,table):
    words,values=features(q)
    candidates=((w,a) for w,a in table if all(
        not t.startswith('@') or int(t[1:])<len(values) for t in a))
    _,answer=max(candidates,key=lambda row:len(words & row[0])/len(words | row[0]))
    return ' '.join(str(values[int(t[1:])]) if t.startswith('@') else t for t in answer)

if __name__=='__main__':
    table=train()
    rng=random.Random(935)
    rows=[gen_asm.make(rng,'sound',held=True) for _ in range(300)]
    from collections import Counter
    import subprocess,zlib
    path=root/'SOUND.BIN'
    crc=zlib.crc32(path.read_bytes())
    if crc>=2**31:crc-=2**32
    answers=subprocess.run([sys.argv[1],str(path),str(crc)],input='\n'.join(q for q,a in rows)+'\n',text=True,capture_output=True,check=True).stdout.splitlines()
    scores=Counter()
    for (q,ref),net in zip(rows,answers,strict=True):
        scores[predict(q,table)==ref,net==ref]+=1
    print('lookup correct, network correct:',scores)
