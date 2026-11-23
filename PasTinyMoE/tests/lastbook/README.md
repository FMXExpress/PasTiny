# SPEC100 on Lastbook topics

SPEC100 at `2084f60` was evaluated against the English topic guides in [Lastbook at f41b6ce](https://github.com/Immortal-Protocols/lastbook/tree/f41b6ce146c9b8ba2eebb1fc769a2ae6ff528095/content/topics). Each row’s topic names its source JSON file. The first 28 questions sample two facts per guide. Six additional questions sample map reading, navigation and electricity, topics with named PasTiny experts. References were written before generation. This samples the topic guides and their reading descriptions, rather than the full referenced library.

The benchmark used the native FPC build of EXPERT.PAS with SPEC100 enabled and the weights and catalog extracted from SPEC100.ZIP. Each question started a fresh process, first in AUTO and, for the six overlap questions, again with USE and the named expert ID. ID zero in AUTO means original Tiny. The model received only the question. The TSV records the actual outputs, including incorrect answers; these are evaluation data.

| Sample | Fully correct AUTO | Partial | Original Tiny selected | Fully correct pinned |
| --- | ---: | ---: | ---: | ---: |
| Practical topics | 1/28 | 2 | 25/28 | — |
| Overlapping vocabulary | 1/6 | 0 | 3/6 | 1/6 |

Manual grading credits equivalent meanings. Listing only resistance for a question asking for all three Ohm’s law quantities earns partial credit. A correct initial “No” followed by unrelated geography also earns only partial credit. The bucket liner count is a correct output on one prompt; it does not establish competence at emergency sanitation. These targeted samples cannot estimate accuracy across the whole library.

[Questions, references, selected models and verbatim outputs](probes.tsv)
