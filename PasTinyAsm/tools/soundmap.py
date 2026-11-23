"""Write normalized examples for streaming SOUND lookup on DOS."""
from pathlib import Path
import sys, struct, random
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'training'))
import gen_asm

def signature(words):
    mask = bytearray(16)
    for word in words:
        h = 0
        for ch in word:
            h = (h * 31 + ord(ch)) % 128
        mask[h // 8] |= 1 << (h % 8)
    return bytes(mask)

def encode(q, answer):
    words = q.split()
    values = []
    for i, w in enumerate(words):
        if w.isdigit() or w in gen_asm.WORDS or w == 'half':
            value = int(w) if w.isdigit() else 0.5 if w == 'half' else gen_asm.WORDS.index(w)
            scale = words[i+1:i+2] in (['second'], ['seconds']) or words[i:i+3] == ['half','a','second']
            values.append(int(value * (1000 if scale else 1)))
            words[i] = 'n' + str(len(values))
    args = answer.split()
    for i, word in enumerate(args):
        if word.isdigit() and int(word) in values:
            args[i] = 'n' + str(values.index(int(word))+1)
    data = ' '.join(args).encode()
    assert len(data) <= 20
    return signature(words) + struct.pack('BB20s', len(values), len(data), data)

if __name__ == '__main__':
    rng = random.Random(11)
    rows = dict.fromkeys(encode(*gen_asm.make(rng,'sound')) for _ in range(4000))
    (root/'SOUND.MAP').write_bytes(b''.join(rows))
