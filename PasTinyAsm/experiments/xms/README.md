# Stream the unchanged Sound expert from XMS

The Turbo Pascal 7 harness caches the original SOUND.BIN in XMS. The loader verifies its CRC and retains the embedding tables and normalization gains in conventional memory. Attention caches stay in conventional memory.

Projection mode stages at most 25,600 bytes and makes six XMS moves per layer. Layer mode stages 89,728 bytes in two blocks of 38,784 and 50,944 bytes to stay within 16-bit segment limits. It makes two XMS moves per layer. Both use the original signed-byte dot product and original row scales. Each move reads the on-disk interleaved scale and weight rows directly. Both paths require an XMS driver.

From PasTinyAsm, generate the first 30 held-out Sound prompts using the fixed seed:

```sh
python3 training/gen_asm.py sound 30 --held --seed 935
```

Write the question field of each JSON line to Q.IN with DOS line endings. Compile BENCH.PAS with the PasTinyAsm sources on the unit path. Build three separate executables with `TPC /B BENCH.PAS`, `TPC /B /DXMSSTREAM BENCH.PAS`, and `TPC /B /DXMSSTREAM;XMSLAYER BENCH.PAS`. Use the standard integer-dot-product configuration. Run each executable with `SOUND.BIN` and its signed decimal CRC32, redirecting input from Q.IN. The harness reports free heap, each exact output line, and two times per prompt in milliseconds. These are time to first emitted character and total inference time.

The experimental flags were tested in the standalone harness. The shipped editor package uses the resident implementation.

## DOSBox-X results

All three TP7 executables returned identical answers on the 30 prompts using the unchanged SOUND.BIN. DOSBox-X used its dynamic core and maximum cycles.

| Weight access | Free heap after allocation | Median first character | Median inference | End-to-end batch |
| --- | ---: | ---: | ---: | ---: |
| Resident | 80,176 B | 264.5 ms | 358 ms | 12.02 s |
| Projection staging | 409,760 B | 255.5 ms | 372 ms | 12.26 s |
| Layer staging | 345,504 B | 273 ms | 389 ms | 12.80 s |

The batch includes emulator startup and model loading. Projection staging freed 329,584 bytes. Layer staging freed 265,328 bytes. The layer buffer's lower XMS call count gave no speed advantage in this emulator sample. Physical Pocket386 latency and the editor's streaming workflow remain unverified.
