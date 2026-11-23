"""Train ternary matrices and export packed weights plus a Pascal-compatible scoring copy."""
import argparse
import random
import struct
import sys
import time
from pathlib import Path

import torch
from torch import nn
from torch.nn import functional as F
from torch.nn.utils import parametrize

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'training'))
sys.path.insert(0, str(root.parent / 'PasTinyJev/training'))
import gen_asm
import webtiny_train as tiny


class Ternary(nn.Module):
    def forward(self, weight):
        scale = weight.detach().abs().mean(dim=1, keepdim=True).clamp_min(1e-8)
        quantized = (weight / scale).round().clamp(-1, 1) * scale
        return quantized.detach() + (weight - weight.detach())


def export(model, path):
    tiny.export_bin(model, path.with_suffix('.BIN'))
    packed = bytearray(struct.pack('<4s4H', b'TTR1', 96, 4, 4, 256))
    for weight in model.tables():
        weight = weight.detach()
        if weight.ndim == 1:
            packed.extend(struct.pack(f'<{weight.numel()}f', *weight.tolist()))
        else:
            for row in weight:
                scale = row.abs().max().item()
                packed.extend(struct.pack('<f', scale))
                values = (row.sign().int() + 1).tolist()
                values.extend([1] * (-len(values) % 4))
                packed.extend(sum(values[i+j] << (2*j) for j in range(4))
                              for i in range(0, len(values), 4))
    path.with_suffix('.TTR').write_bytes(packed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--init', type=Path)
    parser.add_argument('--steps', type=int, default=1200)
    args = parser.parse_args()
    torch.set_num_threads(1)
    torch.manual_seed(42)
    rng = random.Random(11)
    model = tiny.load_bin(args.init) if args.init else tiny.Tiny(96, 4, 4, 256)
    for layer in list(model.modules()):
        if isinstance(layer, (nn.Linear, nn.Embedding)):
            parametrize.register_parametrization(layer, 'weight', Ternary())
    optimizer = torch.optim.AdamW(model.parameters(), lr=.002, weight_decay=0)
    started = time.monotonic()
    for step in range(args.steps):
        pairs = [gen_asm.make(rng, 'sound') for _ in range(32)]
        seq = [[ord(c)-30 for c in q]+[1]+[ord(c)-30 for c in a]+[1] for q,a in pairs]
        width = max(map(len, seq))-1
        x = torch.zeros((len(pairs), width), dtype=torch.long)
        y = torch.full_like(x, -100)
        for i,(s,(q,_)) in enumerate(zip(seq,pairs)):
            x[i,:len(s)-1] = torch.tensor(s[:-1])
            y[i,len(q):len(s)-1] = torch.tensor(s[len(q)+1:])
        optimizer.param_groups[0]['lr'] = .002 * min(1, (step+1)/50) * (0.2 if step >= args.steps*.8 else 1)
        optimizer.zero_grad()
        loss = F.cross_entropy(model(x).flatten(0,1), y.flatten(), ignore_index=-100)
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1)
        optimizer.step()
    export(model,args.output)
    print(f'{args.steps} steps in {time.monotonic()-started:.1f}s; final batch loss {loss.item():.4f}')


if __name__ == '__main__':
    main()
