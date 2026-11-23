"""SVD-initialized low-rank versus single-path binary-factor QAT."""
import argparse
import random
import sys
import time
from pathlib import Path

import torch
from torch import nn
from torch.nn import functional as F

root = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(root / 'training'), str(root.parent / 'PasTinyJev/training')]
import gen_asm
import webtiny_train as tiny


class Factors(nn.Module):
    def __init__(self, weight, rank, binary, dual):
        super().__init__()
        u, s, v = torch.linalg.svd(weight.detach(), full_matrices=False)
        self.left = nn.Parameter(u[:, :rank] * s[:rank].sqrt())
        self.right = nn.Parameter(s[:rank].sqrt()[:, None] * v[:rank])
        self.binary = binary
        if binary:
            self.output_scale = nn.Parameter(self.left.detach().abs().mean(1))
            self.input_scale = nn.Parameter(self.right.detach().abs().mean(0))
            self.latent_scale = nn.Parameter(torch.ones(rank))
            with torch.no_grad():
                if dual:
                    u, singular, v = torch.linalg.svd(self.left.abs(), full_matrices=False)
                    self.output_scale.copy_(u[:, 0].abs() * singular[0])
                    left_latent = v[0].abs()
                    u, singular, v = torch.linalg.svd(self.right.abs(), full_matrices=False)
                    self.input_scale.copy_(v[0].abs() * singular[0])
                    right_latent = u[:, 0].abs()
                    self.latent_scale.copy_(left_latent * right_latent)
                    self.left.div_(left_latent.clamp_min(1e-8))
                    self.right.div_(right_latent[:, None].clamp_min(1e-8))
                self.left.div_(self.output_scale[:, None].clamp_min(1e-8))
                self.right.div_(self.input_scale.clamp_min(1e-8))

    def matrix(self):
        if not self.binary:
            return self.left @ self.right
        def sign_ste(a):
            return torch.where(a >= 0, 1., -1.) + (a - a.detach())
        return ((sign_ste(self.left) * self.output_scale[:, None]) *
                self.latent_scale) @ (sign_ste(self.right) * self.input_scale)

    def forward(self, x):
        return F.linear(x, self.matrix())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('rank', type=int, choices=(8, 16))
    parser.add_argument('--binary', action='store_true')
    parser.add_argument('--dual-svid', action='store_true')
    parser.add_argument('--steps', type=int, default=650)
    args = parser.parse_args()
    if args.dual_svid and not args.binary:
        parser.error("--dual-svid requires --binary")
    torch.set_num_threads(1)
    torch.manual_seed(42)
    rng = random.Random(11)
    model = tiny.load_bin(root / 'SOUND.BIN')
    projections = ('wq', 'wk', 'wv', 'wo', 'f1', 'f2')
    for parameter in model.parameters():
        parameter.requires_grad_(False)
    for block in model.blocks:
        for name in projections:
            setattr(block, name, Factors(getattr(block, name).weight, args.rank, args.binary, args.dual_svid))
    opt = torch.optim.AdamW((p for p in model.parameters() if p.requires_grad), lr=.002, weight_decay=0)
    start = time.monotonic()
    for step in range(args.steps):
        pairs = [gen_asm.make(rng, 'sound') for _ in range(32)]
        seqs = [[ord(c)-30 for c in q]+[1]+[ord(c)-30 for c in a]+[1] for q, a in pairs]
        x = torch.zeros((len(pairs), max(map(len, seqs))-1), dtype=torch.long)
        y = torch.full_like(x, -100)
        for i, (seq, (q, _)) in enumerate(zip(seqs, pairs)):
            x[i, :len(seq)-1] = torch.tensor(seq[:-1])
            y[i, len(q):len(seq)-1] = torch.tensor(seq[len(q)+1:])
        opt.param_groups[0]['lr'] = .002 * min(1, (step+1)/50) * (.2 if step >= args.steps*.8 else 1)
        opt.zero_grad()
        loss = F.cross_entropy(model(x).flatten(0,1), y.flatten(), ignore_index=-100)
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1)
        opt.step()
    dense = tiny.load_bin(root / 'SOUND.BIN')
    with torch.no_grad():
        for original, adapted in zip(dense.blocks, model.blocks):
            for name in projections:
                getattr(original, name).weight.copy_(getattr(adapted, name).matrix())
    tiny.export_bin(dense, args.output)
    print(f'{args.steps} steps in {time.monotonic()-start:.1f}s, final batch loss {loss.item():.4f}')


if __name__ == '__main__':
    main()
