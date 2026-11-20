# SPEC20 expert batch

The DOS package contains 20 distinct trained models. This batch adds ten. The host evaluation used 148 held-out prompts covering the new experts. Automatic routing and forced expert selection each produced 120 exact answers. The DOS Guide baseline produced zero. These scores measure the supplied prompts, including alternate phrasings of training facts.

| Expert | Exact answers with automatic routing |
| --- | ---: |
| [047 Antonyms](047/README.md) | 23/24 |
| [048 Abbreviations](048/README.md) | 9/24 |
| [049 Idioms](049/README.md) | 12/12 |
| [050 Word origins](050/README.md) | 12/12 |
| [052 Mammals](052/README.md) | 9/12 |
| [053 Birds](053/README.md) | 9/12 |
| [054 Reptiles](054/README.md) | 17/18 |
| [055 Amphibians](055/README.md) | 17/18 |
| [056 Fish](056/README.md) | 5/8 |
| [057 Insects](057/README.md) | 7/8 |

[DOS package](../../dist/SPEC20.ZIP) · [Individual model files](../models/) · [Per-prompt results](answers.jsonl)
