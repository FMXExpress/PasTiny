# Fixed-point RMS experiment

The `FIXEDRMS` build flag tests one change toward integer inference using the shipped 8-bit weights. RMS energy is accumulated in a signed 32-bit integer. The input scale limits the magnitude to 4095, so the sum of 96 squared entries fits. An integer Newton iteration computes the floor of its square root. This build still converts from float activations and applies float gains. The attention exponential lookup remains as before, including its float input and scaling.

Build from PasTinyAsm with FPC:

```sh
mkdir -p build/fixed-rms
fpc -B -Mtp -O2 -dFIXEDRMS -Fu. -FUbuild/fixed-rms -FEbuild/fixed-rms experiments/classic/check.pas
python3 experiments/ternary/score.py build/fixed-rms/check SOUND.BIN
```

Both the ordinary and FIXEDRMS builds scored 208/300 exact commands on the held-out Sound sample. Output matched on 298/300 prompts. Turbo Pascal 7 built both versions. In DOSBox-X, 12 repetitions of “play a siren” returned SIREN 2 every time. Wall times including startup and model loading were 3.54 and 3.48 seconds for the baseline, and 3.63 and 3.81 seconds for FIXEDRMS. This measures the hybrid normalization change in the emulator, with the software-FPU-free build and physical Pocket386 speed still open.
