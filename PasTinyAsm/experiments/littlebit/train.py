"""SVD-initialized low-rank versus single-path binary-factor QAT."""
import argparse
import random
import sys
import struct
import time
from pathlib import Path

import torch
from torch import nn
from torch.nn import functional as F

root = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(root / 'training'), str(root.parent / 'PasTinyJev/training')]
import gen_asm
import gen_tasks
import gen_recipes
import webtiny_train as tiny


class Factors(nn.Module):
    def __init__(self, weight, rank, binary, dual):
        super().__init__()
        u, s, v = torch.linalg.svd(weight.detach(), full_matrices=False)
        self.left = nn.Parameter(u[:, :rank] * s[:rank].sqrt())
        self.right = nn.Parameter(s[:rank].sqrt()[:, None] * v[:rank])
        self.binary = binary
        self.ternary = False
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

    def enable_ternary(self):
        with torch.no_grad():
            output = self.left.abs().mean(1).clamp_min(1e-8)
            inputs = self.right.abs().mean(0).clamp_min(1e-8)
            self.left.div_(output[:, None])
            self.right.div_(inputs)
        self.output_scale = nn.Parameter(output)
        self.input_scale = nn.Parameter(inputs)
        self.latent_scale = nn.Parameter(torch.ones(self.left.shape[1]))
        self.ternary = True

    def matrix(self):
        if self.ternary:
            def quantize(a):
                return a.detach().round().clamp(-1, 1) + (a - a.detach())
            return ((quantize(self.left) * self.output_scale[:, None]) *
                    self.latent_scale) @ (quantize(self.right) * self.input_scale)
        if not self.binary:
            return self.left @ self.right
        def sign_ste(a):
            return torch.where(a >= 0, 1., -1.) + (a - a.detach())
        return ((sign_ste(self.left) * self.output_scale[:, None]) *
                self.latent_scale) @ (sign_ste(self.right) * self.input_scale)

    def forward(self, x):
        return F.linear(x, self.matrix())


def export_packed(model, dense_path, output, projections):
    dense = dense_path.read_bytes()
    # Header and two ordinary TNY2 embedding tables.
    packed = bytearray(b'TF16' + dense[4:22512])
    for block in model.blocks:
        for name in projections:
            if name in ('wq', 'f1'):
                gain = block.g1 if name == 'wq' else block.g2
                packed.extend(struct.pack('<96f', *gain.detach().tolist()))
            layer = getattr(block, name)
            for scale in (layer.input_scale, layer.latent_scale, layer.output_scale):
                packed.extend(struct.pack(f'<{scale.numel()}f', *scale.detach().tolist()))
            for factor in (layer.right, layer.left):
                digits = (factor.detach().round().clamp(-1, 1).int().flatten()+1).tolist()
                packed.extend(sum(digits[i+j] << (2*j) for j in range(4))
                              for i in range(0, len(digits), 4))
    packed.extend(dense[-384:])
    assert len(packed) == 74608
    output.write_bytes(packed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('rank', type=int, choices=(8, 16))
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--binary', action='store_true')
    mode.add_argument('--ternary-steps', type=int, default=0)
    parser.add_argument('--dual-svid', action='store_true')
    parser.add_argument('--expert', choices=('screen','sound','text','tasks','recipes','slots'), default='sound')
    parser.add_argument('--packed', type=Path)
    parser.add_argument('--steps', type=int, default=650)
    args = parser.parse_args()
    if args.steps < 1 or args.ternary_steps < 0:
        parser.error("require positive float or binary steps and nonnegative ternary steps")
    if args.dual_svid and not args.binary:
        parser.error("--dual-svid requires --binary")
    if args.packed and (args.rank != 16 or not args.ternary_steps):
        parser.error("--packed requires rank 16 and ternary fine-tuning")
    torch.set_num_threads(1)
    torch.manual_seed(42)
    rng = random.Random(11)
    base = root / (args.expert.upper() + '.BIN')
    model = tiny.load_bin(base)
    projections = ('wq', 'wk', 'wv', 'wo', 'f1', 'f2')
    for parameter in model.parameters():
        parameter.requires_grad_(False)
    for block in model.blocks:
        for name in projections:
            setattr(block, name, Factors(getattr(block, name).weight, args.rank, args.binary, args.dual_svid))
    opt = torch.optim.AdamW((p for p in model.parameters() if p.requires_grad), lr=.002, weight_decay=0)
    start = time.monotonic()
    for index in range(args.steps + args.ternary_steps):
        if index == args.steps:
            for block in model.blocks:
                for name in projections:
                    getattr(block, name).enable_ternary()
            opt = torch.optim.AdamW((p for p in model.parameters() if p.requires_grad),
                                    lr=.002, weight_decay=0)
        phase_steps = args.steps if index < args.steps else args.ternary_steps
        step = index if index < args.steps else index - args.steps
        if args.expert in ('tasks', 'slots'):
            draw = lambda: gen_tasks.make(rng, slots=args.expert == 'slots')
        elif args.expert == 'recipes':
            draw = lambda: gen_recipes.make(rng)
        else:
            draw = lambda: gen_asm.make(rng, args.expert)
        pairs = [draw() for _ in range(32)]
        seqs = [[ord(c)-30 for c in q]+[1]+[ord(c)-30 for c in a]+[1] for q, a in pairs]
        x = torch.zeros((len(pairs), max(map(len, seqs))-1), dtype=torch.long)
        y = torch.full_like(x, -100)
        for i, (seq, (q, _)) in enumerate(zip(seqs, pairs)):
            x[i, :len(seq)-1] = torch.tensor(seq[:-1])
            y[i, len(q):len(seq)-1] = torch.tensor(seq[len(q)+1:])
        opt.param_groups[0]['lr'] = .002 * min(1, (step+1)/50) * (.2 if step >= phase_steps*.8 else 1)
        opt.zero_grad()
        loss = F.cross_entropy(model(x).flatten(0,1), y.flatten(), ignore_index=-100)
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1)
        opt.step()
    dense = tiny.load_bin(base)
    with torch.no_grad():
        for original, adapted in zip(dense.blocks, model.blocks):
            for name in projections:
                getattr(original, name).weight.copy_(getattr(adapted, name).matrix())
    tiny.export_bin(dense, args.output)
    if args.packed:
        export_packed(model, args.output, args.packed, projections)
    print(f'{args.steps + args.ternary_steps} steps in {time.monotonic()-start:.1f}s, final batch loss {loss.item():.4f}')


if __name__ == '__main__':
    main()
