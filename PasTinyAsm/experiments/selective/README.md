# Can uncertainty catch wrong accepted text lines?

The native FPC editor used the shipped experts and normal validation with guided writing enabled. The sample is the existing text expert test: 300 generated prompts in new wordings (seed 5), after advancing through the two earlier wording sets. A separate draw from those templates (seed 935) selected the threshold. Exact command equality is the scoring criterion.

| Policy | Exact | Wrong accepted | Refused |
| --- | ---: | ---: | ---: |
| Shipped selection | 113 | 187 | 0 |
| Refuse below calibrated margin | 113 | 187 | 0 |
| Vote with shipped selection as fallback | 113 | 187 | 0 |
| Require a vote for model-generated lines | 0 | 5 | 295 |

Threshold selection retained at least 95% of the calibration set's exact answers and prioritized reducing wrong accepted lines. The selected minimum raw top-two score gap was 1.6. Calibration rejected three wrong lines and retained all 127 exact lines. The threshold flagged no test lines. It uses the first generation’s minimum margin, including the end token, before guidance filters candidates. A fallback answer inherits the first generation’s margin in this experiment.

The vote compares the first generation and up to three second-choice continuations. Every candidate passes the editor’s existing checks before counting. A winner needs at least two votes and more than half the valid votes. PRINT, ECHO and newline commands are grouped by output text and trailing newline; other commands are grouped by exact command. This is a small text-behavior comparison. It does not execute arbitrary programs. Each continuation starts with a fresh copy of the greedy inference state. The uninstrumented run reproduced the same baseline scores.

Run from PasTinyAsm with FPC installed:

```sh
mkdir -p build/selective
cp *.PAS *.INC *.BIN EXPERTS.CAT build/selective/
python3 experiments/selective/instrument.py build/selective
(cd build/selective && fpc -B -Mtp -O2 -oMAKECOM TRACE.PAS)
python3 experiments/selective/score.py build/selective
```
