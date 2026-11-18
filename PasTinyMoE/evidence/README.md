# Validation records

The TP7 target is a DOS real-mode executable built from the same sources for both capacities. INTEGER.LOG, NOASM.LOG, FLOAT.LOG and DEBUG.LOG record clean rebuilds. The development reference is PasTiny commit 619052aab899ad837b003093752bc36008558eff. The baseline subdirectory includes an instrumentation patch for the three memory readings.

## Memory and recovery

In DOSBox-X 2025.02.01 with a normal 386 core, 16 MB and FPU disabled, the production build started with 533,360 bytes of free heap. After reserving the model and inference buffers, MemAvail and MaxAvail were both 49,160 bytes. The 300-switch loop, followed by selections 64 and 100, ended with both values still at 49,160 bytes. The stack pointer at the reporting calls was 15,860 within the 16 KiB stack. These are snapshots at the reporting sites. The baseline probe measured 531,632 bytes before loading and 47,432 after loading and after one query.

SWITCH.IN and SWITCH.LOG contain the load-only sequence. The first USE selects the already resident model and avoids a reread. TRY.IN and TRY.LOG exercise a missing replacement in DOS. On Linux, read_faults.py injects EIO during a model read, then exercises the case where both replacement and recovery reads fail. The latter ends in the unloaded state. The host tests also cover malformed catalog records, capacities 3/100/128, rejection of 129, truncated and appended weights, bad header and dimensions, a nonfinite scalar, and a bad CRC32. All tests use the general model.

## Timing scope

The fixed directory records DOSBox-X with a normal 386 core, 50,000 fixed cycles, 16 MB and FPU disabled. REP1 through REP3 use the identical CHECK.IN, greedy generation and five-character answer “Lima.”. Cold startup is timed externally using the parent repository's BENCH/BMRUN.EXE, from process launch until exit after reading QUIT. This includes executable initialization, catalog parsing, the first validated model load, inference workspace initialization and shutdown.

| Measurement | Median | Observed range |
|---|---:|---:|
| Cold process, immediate QUIT, 3 runs | 443 ms | 442–443 ms |
| First validated load inside CHECK, 3 runs | 318 ms | 266–319 ms |
| Warm pinned answer, 3 runs | 16,508 ms | 16,453–16,508 ms |
| Warm input through first output character, 3 runs | 13,771 ms | 13,717–13,772 ms |
| Warm output rate after first character, 4 timed character intervals, 3 runs | 1.84 chars/s | 1.79–1.84 chars/s |
| Routing 30,000 identical prompts with 3 cached catalog entries, 3 batches | 424 ms | 369–424 ms |
| Routing 30,000 identical prompts with 100 cached catalog entries, 3 batches | 923 ms | 923–923 ms |

The router's startup file access is included in catalog/init. Subsequent routes read the resident catalog. The first-character interval includes prefill, selection and callback entry. Output span measures first to last character callback. Total answer time also includes end-of-answer inference. Redirected output uses DOS buffering. Clock quantization can affect sub-tick readings. The max-cycle configuration used for correctness and stress tests is recorded separately. No physical Pocket386 measurements are available.

The pinned integer, NOASM and float baseline executables rebuilt byte-for-byte with TP7. Each reproduced the 60-answer transcript with the emulated FPU enabled. The production build loads a resident model plus query buffers using 484,200 bytes from the heap. The comparison tools, compiler and test corpora are excluded from both runtime editions.

All 60 greedy answers matched the original C transcript on the production TP7 build with FPU disabled, and on each of the ASM, NOASM and float builds with FPU enabled. The rebuilt legacy integer executable also matched all 60 under the no-FPU configuration. FLOAT-OFF.LOG records a separate software-float smoke on the new float build. The three fixed-cycle alternating-expert runs completed two queries each in a median 33.725 seconds from external launch through exit (33.724–33.727).
