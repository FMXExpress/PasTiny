# 020 PC expansion slots

Four identifications cover the IBM PC/AT lineage of ISA, Micro Channel in many PS/2 models, VESA Local Bus on 486 boards, and the processor-independent PCI local bus. Answers give the corresponding abbreviation. [ISA](https://en.wikipedia.org/wiki/Industry_Standard_Architecture) · [MCA](https://en.wikipedia.org/wiki/Micro_Channel_architecture) · [VLB](https://en.wikipedia.org/wiki/VESA_Local_Bus) · [PCI](https://en.wikipedia.org/wiki/Peripheral_Component_Interconnect)

Training used 48 prompts. Direct expert selection in the native Pascal runtime yielded 10/12 exact answers on held-out rephrasings. [Per-question results](oracle.jsonl)

From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/020
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch90/020/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/020/model.bin
```
