# What the 60 PasTinyMoE experts answer

AUTO uses keywords and context to choose one trained model. DOS loads its 381,808-byte weights and generates a short answer. When the router needs the user to pick a model it prompts for a selection. The original general weights can be run separately.

## Same prompts, two models

Host Pascal ran both sets of weights at the default deterministic settings. The original 60 questions use the C transcript as the expected text. The specialist questions use the expert authors’ expected answers and include alternate phrasings of the trained facts or character lines. The score counts complete string matches, including punctuation.

| Prompt set | Original weights, exact | SPEC60 AUTO, exact | Asked for expert selection |
| --- | ---: | ---: | ---: |
| Original 60 | 60/60 | 3/60 | 47 |
| First 50 experts | 6/748 | 633/748 | 0 |
| Latest ten experts | 1/136 | 121/136 | 0 |
| All 60 experts | 7/884 | 754/884 | 0 |

The first 50 and latest ten rows partition the 60-expert total. The total weights each recorded prompt equally. On the original questions, “where is the eiffel tower” received “Paris.” against the reference “Paris, France.” Other misses are factual. For “how many moons does mars have” the reference says “Two.” and the routed model answered “Mars has four legs.” An exact-match miss alone does not distinguish a wrong fact from a shorter acceptable answer.

## Expert scores and example tasks

The example column gives one real question and its expected answer from each expert’s evaluation. The counts measure this specific syllabus. A perfect score can cover only a handful of facts.

| ID | Expert | Routed correctly | Exact | Example question → expected answer |
| ---: | --- | ---: | ---: | --- |
| 001 | DOS Guide | 11/11 | 6/11 | what command lists my files → DIR. |
| 002 | Turbo Pascal Coach | 11/11 | 9/11 | which operator computes an integer quotient → div. |
| 003 | PC Workbench | 21/21 | 14/21 | why does a program need ram → Holds working data while powered. |
| 041 | Word Bench | 24/24 | 24/24 | in a few words what is meant by brief → Short in duration. |
| 042 | Spelling Helper | 18/18 | 10/18 | what should i write instead of recieve → receive |
| 043 | Confused Words | 18/18 | 17/18 | i mix these words up what does affect stand for → Usually a verb meaning influence. |
| 044 | Grammar Terms | 18/18 | 9/18 | what function does the term noun describe → Names a person, place, thing or idea. |
| 045 | Punctuation | 30/30 | 22/30 | give me a short explanation of the comma → Separates items in a list. |
| 046 | Synonyms | 32/32 | 25/32 | could you give one synonym for brief → short |
| 047 | Antonyms | 24/24 | 23/24 | for a visit what is an antonym for brief → long |
| 048 | Abbreviations | 24/24 | 9/24 | my envelope says az what state am i mailing to → Arizona |
| 049 | Idioms | 12/12 | 12/12 | what idea is expressed by the saying break the ice → Make people feel at ease. |
| 050 | Word origins | 12/12 | 12/12 | tell me how the english term algebra came to us → From Arabic via Medieval Latin. |
| 051 | Pocket Naturalist | 11/11 | 11/11 | how many walking legs has a spider → Eight. |
| 052 | Mammals | 12/12 | 9/12 | what part of an elephant serves as a nose → A long nose. |
| 053 | Birds | 12/12 | 9/12 | how are penguin wings used underwater → Flippers for swimming. |
| 054 | Reptiles | 18/18 | 17/18 | to which animal group does a tortoise belong → A reptile. |
| 055 | Amphibians | 18/18 | 17/18 | which amphibian group includes the axolotl → A salamander. |
| 056 | Fish | 8/8 | 5/8 | atlantic salmon swim inland to spawn in which kind of water → Fresh water. |
| 057 | Insects | 8/8 | 7/8 | a butterfly egg hatches into what kind of larva → A caterpillar. |
| 058 | Spiders | 10/10 | 9/10 | a spider makes a thread what comes out of its spinnerets → Release silk. |
| 059 | Trees | 12/12 | 11/12 | what travels upward through the xylem → Transports water and minerals. |
| 060 | Flowers | 8/8 | 6/8 | what is the anther responsible for in a flower → Produces pollen. |
| 061 | Solar system | 8/8 | 8/8 | of the planets which orbits the sun most closely → Mercury. |
| 062 | Stars and Sky | 18/18 | 15/18 | what is another name for polaris → The North Star. |
| 063 | Weather | 18/18 | 13/18 | what is fog near the ground → A cloud touching the ground. |
| 064 | Rocks and geology | 12/12 | 12/12 | give the geological class of granite → Igneous. |
| 065 | Electricity | 12/12 | 9/12 | which quantity corresponds to the unit volt → Potential difference. |
| 066 | Forces and motion | 18/18 | 16/18 | why does inertia matter when an object starts moving → Resistance to changes in velocity. |
| 067 | Light | 18/18 | 15/18 | what happens to light during reflection from a mirror → Light bouncing from a surface. |
| 068 | Sound | 12/12 | 11/12 | which wave quantity does pitch follow → Frequency. |
| 069 | Elements and Matter | 12/12 | 11/12 | give the periodic table abbreviation for sodium → Na. |
| 070 | Human Body | 18/18 | 18/18 | which system has the heart and blood vessels → The cardiovascular system. |
| 071 | Countries and Capitals | 18/18 | 18/18 | if i ask for the capital city of finland what is the answer → Helsinki. |
| 072 | Flags | 8/8 | 7/8 | what would i see on the flag flown by japan → A red disc on white. |
| 073 | Continents | 8/8 | 7/8 | which of the continents has the greatest land area → Asia. |
| 074 | Rivers | 12/12 | 12/12 | give a continental location for the nile → Africa. |
| 075 | Mountains | 12/12 | 12/12 | give a continental location for the andes → South America. |
| 076 | Oceans and seas | 18/18 | 17/18 | what major land areas face the pacific from east and west → The Americas, Asia and Australia. |
| 077 | Cities | 18/18 | 18/18 | which country would i go to for a visit to osaka → Japan. |
| 078 | Landmarks | 12/12 | 12/12 | which city has the famous eiffel tower → Paris. |
| 079 | Map Reader | 12/12 | 9/12 | what purpose does the legend on a map serve → Explains symbols. |
| 080 | Navigation Terms | 18/18 | 18/18 | on a compass what bearing is northeast → 45 degrees. |
| 081 | Ancient Egypt | 18/18 | 18/18 | what was khufu in egypt → A pharaoh. |
| 082 | Ancient Greece | 8/8 | 7/8 | who was the goddess worshiped at the parthenon → Athena. |
| 083 | Ancient Rome | 8/8 | 8/8 | who is credited with writing the roman epic aeneid → Virgil. |
| 084 | Medieval life | 12/12 | 10/12 | how would a medieval cooper spend a working day → Made wooden barrels. |
| 085 | Exploration | 12/12 | 7/12 | what was the name of the ship carrying cook in 1768 → Endeavour. |
| 086 | Inventions | 18/18 | 14/18 | which french physician invented the stethoscope → Rene Laennec. |
| 087 | Computing history | 18/18 | 18/18 | which year saw eniac public dedication → 1946. |
| 088 | Spaceflight | 12/12 | 9/12 | when did the first sputnik satellite launch → 1957. |
| 089 | Transport History | 12/12 | 11/12 | when did the wright flyer make its first powered flight → 1903. |
| 090 | History vocabulary | 18/18 | 16/18 | how would a historian define chronology → The order of events in time. |
| 091 | Riddle hints | 18/18 | 17/18 | nudge me on the silver twin riddle → Look for a smooth surface. |
| 092 | Wordplay | 8/8 | 8/8 | describe the pattern in a palindrome → It reads the same backward and forward. |
| 093 | Chess vocabulary | 8/8 | 8/8 | what conditions identify stalemate → No legal move and the king is not in check. |
| 094 | Adventure vocabulary | 12/12 | 10/12 | what should the adventure parser do when i enter look → Describe the current room. |
| 095 | Dungeon descriptions | 12/12 | 10/12 | give the player a glimpse of the dungeon cistern → Drops ring in the black pool. |
| 096 | Pirate character | 18/18 | 17/18 | pirate give us your greeting → Ahoy, matey! |
| 097 | Spaceship character | 18/18 | 15/18 | spaceship give us your greeting → Welcome aboard, captain. |

[All questions, targets and both generated answers](comparison.jsonl) · [Original 60 questions](../../../tests/questions.txt) · [Original port comparison](../../../tests/run_host.sh)

To repeat the paired comparison, run `python specialists/batch60/compare_original.py HOST_EXE build/SPEC60 dist/FLOPPY3` from PasTinyMoE with the SPEC60 host executable and both expanded DOS packages.
