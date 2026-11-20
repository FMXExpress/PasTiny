# 091 Riddle hints

Ask for a clue using the title of one of these six original riddles. The training answers give one clue per title.

| Title | Riddle |
| --- | --- |
| Silver Twin | I copy every wink you make and never blink alone. Where do I live? |
| Hungry Teeth | My teeth take tidy paths through tangles, yet I never eat. What am I? |
| Paper Traveler | I circle the world stuck to one corner. What pays my way? |
| Quiet Climber | With green hands I scale the brickwork and never look down. What am I? |
| Melted Tower | My bright rooftop sinks lower each night I work. What am I? |
| Round Runner | My feet take turns touching the street, but my body has no legs. What am I? |

There are 72 training prompts and 18 held-out rephrasings of the six subjects. From PasTinyMoE, set WEBTINY to the WebTiny checkout at a1a36720ed558d6998e5beed9d4dbdd792626056 and run

```sh
mkdir -p build/091
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch60/091/train.jsonl --threads 1 --steps 450 --batch-size 8 --lr .00035 --out build/091/model.bin
```

The native Pascal runtime loaded this expert directly and answered 17/18 held-out questions exactly. [Per-question results](oracle.jsonl)
