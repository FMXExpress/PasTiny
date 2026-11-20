# 065 · Electricity

This pilot names the physical quantity measured by six common SI units used in circuit descriptions.

| Unit | Target quantity |
|---|---|
| volt | Potential difference |
| ampere | Electric current |
| ohm | Electrical resistance |
| watt | Power |
| farad | Capacitance |
| hertz | Frequency |

The ampere is the base unit of electric current. The other five mappings appear in the derived-units table of NIST Special Publication 330. Hertz applies to periodic phenomena. [NIST electric current](https://www.nist.gov/pml/owm/si-units-electric-current) · [NIST SP 330, tables 2 and 4](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.330-2019.pdf)

The 108 original development records vary unit names, plural forms and question templates. Each of the six units has one new pattern and one individual held-out question. All 12 probes were frozen before training. The scope is unit-to-quantity vocabulary for low-voltage circuits. The expert has no connection to meters or live hardware and does no circuit calculations.

## Reproduction

Run from PasTinyMoE with WEBTINY at a1a36720ed558d6998e5beed9d4dbdd792626056, CPU PyTorch 2.15 and default seed 42.

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data specialists/batch30/065/train.jsonl --steps 550 \
  --threads 1 --batch-size 10 --lr .00035 --out build/065/model.bin
```
