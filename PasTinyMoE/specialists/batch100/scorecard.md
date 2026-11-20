# SPEC100 paired evaluation

The native Pascal runtime answered each question twice, first with the original Tiny weights pinned and then with SPEC100 automatic routing. Original questions use the C transcript as their reference. Specialist questions test alternate phrasings of covered material and use each expert’s published reference answers. Exact match includes punctuation. A request to select an expert counts as a miss.

| Prompt set | Original exact | SPEC100 AUTO exact | Asked for selection |
| --- | ---: | ---: | ---: |
| Original 60 questions | 60/60 | 3/60 | 47 |
| Previous 90 experts | 7/1273 | 1056/1273 | 0 |
| Latest ten experts | 0/108 | 82/108 | 0 |
| All 100 experts | 7/1381 | 1138/1381 | 0 |

## Per-expert results

Each example pairs a held-out question with its reference answer. Routing and exact answers are scored independently. Each prompt has equal weight in the totals.

| ID | Expert | Routed correctly | Exact | Example question → reference |
| ---: | --- | ---: | ---: | --- |
| 001 | DOS Guide | 11/11 | 6/11 | what command lists my files → DIR. |
| 002 | Turbo Pascal Coach | 11/11 | 9/11 | which operator computes an integer quotient → div. |
| 003 | PC Workbench | 21/21 | 14/21 | why does a program need ram → Holds working data while powered. |
| 004 | File and Path Terms | 12/12 | 12/12 | what does a pathname identify in dos → A file or directory location. |
| 005 | DOS memory terms | 15/15 | 10/15 | what is the low 640k region called conventional memory → The first 640 KB of PC address space. |
| 006 | Floppy disk terms | 14/14 | 11/14 | what should i understand by track in a floppy manual → A circular recording path on one side. |
| 007 | FAT Volume Terms | 8/8 | 1/8 | what does a cluster group together on a fat volume → Group of sectors allocated as one unit. |
| 008 | DOS Startup Files | 6/6 | 4/6 | what is the role of config.sys during ms dos startup → Sets system options and loads drivers. |
| 009 | Batch file vocabulary | 18/18 | 12/18 | what does echo hello print → It displays hello. |
| 010 | Text file conventions | 18/18 | 12/18 | which ascii number is a carriage return → ASCII 13. |
| 011 | Keyboard terminology | 12/12 | 12/12 | how should a beginner understand scan code in a keyboard guide → A code that identifies a physical key. |
| 012 | BIOS setup glossary | 12/12 | 10/12 | how should a beginner understand post in a bios guide → Power-on self-test checks hardware at startup. |
| 013 | Display adapters | 18/18 | 17/18 | what are the dimensions of the mda text screen → 80 columns by 25 rows. |
| 014 | Text screen layout | 18/18 | 14/18 | how many bytes does one color text cell occupy → 2 bytes. |
| 015 | Bitmap graphics | 8/8 | 6/8 | what does pixel mean in a bitmap → One picture element. |
| 016 | Printer desk | 8/8 | 6/8 | how does a tractor printer grip continuous paper → Pins engage holes along the paper edges. |
| 017 | Joystick Desk | 10/10 | 6/10 | which direction does the joystick x axis measure → Left and right movement. |
| 018 | PC Audio Devices | 8/8 | 5/8 | what audio device made simple tones inside an early pc → Built-in speaker for simple tones. |
| 019 | Serial port glossary | 12/12 | 9/12 | what unit counts symbols sent each second → Symbols transmitted per second. |
| 020 | PC expansion slots | 12/12 | 10/12 | which bus extended the original pc design to 16 bits in the at → ISA. |
| 021 | Pascal scalar types | 10/10 | 6/10 | summarize the following declaration: var x: boolean; → It holds False or True. |
| 022 | Pascal control flow | 10/10 | 10/10 | summarize the following snippet: if ok then inc(n); → Increment n only if ok is true. |
| 023 | Pascal records and arrays | 18/18 | 16/18 | which symbol selects a field of a pascal record → A dot. |
| 024 | Pascal routines | 18/18 | 16/18 | which pascal routine kind has no function result → Procedure. |
| 025 | Pascal file types | 8/8 | 6/8 | which elements belong in a typed file → Elements of one declared type. |
| 026 | Pascal units | 8/8 | 8/8 | which names appear in a unit interface → It declares the public names. |
| 027 | Compiler Messages | 8/8 | 6/8 | why does assigning true to an integer cause type mismatch → The types are incompatible. |
| 028 | Debugger Vocabulary | 8/8 | 5/8 | what happens when a debugger reaches a breakpoint → Pauses execution at a chosen location. |
| 029 | Number notation | 12/12 | 9/12 | what base uses only zero and one → Binary uses base two. |
| 030 | Boolean logic | 12/12 | 4/12 | when is a two input and gate true → True when both inputs are true. |
| 031 | Sorting vocabulary | 8/8 | 6/8 | recognize this sorting example: the field that determines record order → Sort key. |
| 032 | Data structures | 6/6 | 5/6 | identify a structure with this rule: last in first out → Stack. |
| 033 | Archive formats | 18/18 | 17/18 | what filename extension identifies a ZIP archive → .zip |
| 034 | Spreadsheet formulas | 18/18 | 17/18 | is spreadsheet reference A1 relative or absolute → Relative. |
| 035 | Database vocabulary | 8/8 | 5/8 | explain the structure of a table in a database → Related records arranged in rows and columns. |
| 036 | Text editor navigation | 10/10 | 8/10 | what does the caret tell an editor user → It marks the current insertion point. |
| 037 | Modem Desk | 12/12 | 9/12 | which dialing mode does modem command atdt select → Tone dial. |
| 038 | BBS and Terminal | 12/12 | 4/12 | who is called the sysop on a bulletin board → System operator. |
| 039 | WordStar | 18/18 | 13/18 | how can i save my wordstar file and keep editing? → Ctrl-K S. |
| 040 | Lotus 1-2-3 | 18/18 | 12/18 | which key edits the current lotus spreadsheet cell? → F2. |
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
| 098 | Frontier character | 18/18 | 18/18 | frontier give us your greeting → Howdy, traveler! |
| 099 | Fairy-tale character | 18/18 | 16/18 | fairytale give us your greeting → Welcome to the willow court! |
| 100 | Story sparks | 12/12 | 11/12 | offer one story beginning inspired by a thimble → A thimble holds the last rain on Earth. |
