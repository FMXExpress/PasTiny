# SPEC3 router benchmark

The comparison uses the three fixed model hashes in the [pilot manifest](../manifest.json), greedy inference and the same prompts on both builds. The reference is PasTiny commit 540fe50. The 15 fresh prompts and labels were written before measuring the old router or editing its rules. The suite is small and developer-authored. Original questions come from the pilot's separate 24-prompt evaluation.

| Test | Original AUTO | Revised AUTO | Pinned specialist |
|---|---:|---:|---:|
| Correct expert on 24 original questions | 16/24 | 24/24 | 24/24 |
| Exact answer on those questions | 13/24 | 19/24 | 19/24 |
| Correct expert on 6 fresh bare questions | 2/6 | 6/6 | 6/6 |
| Exact answer on those bare questions | 0/6 | 3/6 | 3/6 |
| Exact answer on 3 fresh tagged questions | 1/3 | 1/3 | 1/3 |
| Clarified ambiguous prompts | 0/3 | 3/3 | — |
| Clarified unknown prompts | 0/3 | 3/3 | — |

The general model scored 0/9 exact on the fresh in-scope prompts. All 33 paired pinned answers matched byte for byte between builds. Clarifications are counted separately from correct answers. AUTO matches case-insensitive whole words against three small syllabus vocabularies. With zero or multiple matching domains, it requests a manual choice before loading weights or calling inference. Domain keywords are evidence of topic, so questions outside the syllabus that still contain a matching word can still route to an expert.

The remaining five fresh in-scope misses were all reproduced with manual selection. The Pascal expert returned “div.” for a remainder question and the DOS expert returned “TYPE.” for a directory listing. The next quality experiment should train on contrasting operations, then score a newly frozen set of paraphrases. Reusing these 15 prompts to tune weights would weaken the assessment.

## Reproduction

Build the host comparison executable with FPC using `-dSPEC3 -B EXPERT.PAS`. Use the unmodified baseline executable for the before run. Invoke `python specialists/routing/compare.py EXE SPEC3_DIRECTORY OUTPUT.jsonl` for each. The specialized TP7 build uses `TPC /B /DSPEC3 EXPERT.PAS`. BUILD.BAT saves this executable under SPEC3.EXE. The packaging script reads bin/SPEC3.EXE and writes EXPERT.EXE on the DOS media. Other build modes use the original catalog router.

RTPROF.PAS calls the real Route function 8,000 times per batch, using three supported topics and one unknown. The checksum accumulates catalog indices. Build the harness with the same defines as the executable. DOS performance runs use the normal 386 core at 50,000 fixed cycles, 16 MB, FPU disabled and redirected output. The heap test loads the Pascal expert, generates a warm answer, then cycles through all three specialists 300 times without generation. In a separate batch, the warm-input test repeats one tagged question three times. These are emulator measurements.

| Fixed-cycle DOSBox-X measurement | Baseline | Revised |
|---|---:|---:|
| Router microseconds per question, median batch | 20.375 | 100.75 |
| Validated switch ms, median of 300 | 316.5 | 316.0 |
| Warm first-character ms, median of 3 | 19,234 | 19,234 |
| Warm total answer ms, median of 3 | 21,546 | 21,545 |
| Free heap and largest free block after 300 switches, bytes | 49,160 | 48,408 |

The revised router uses 752 additional bytes of conventional memory in this build. Neither run lost heap across the 300 switches. The independent FPU-enabled TP7 replay reproduced all 72 host answer or clarification outcomes. The trained weights were verified byte-for-byte in the rebuilt ZIP. The FAT12 image passed copy-back verification. Physical hardware was unavailable.
