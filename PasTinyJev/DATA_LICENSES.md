# Data licences

`training/distill.jsonl.gz` holds short messages with labels from a local OpenJev server
(the Laya model). The messages come from three sources, named in each record's `src` field:

| `src` | Source | Licence |
|---|---|---|
| `template` | Written for this project (`training/gen_jev.py`) | MIT, as the code |
| `banking77` | [PolyAI/banking77](https://huggingface.co/datasets/PolyAI/banking77), Casanueva et al. 2020 | CC BY 4.0 |
| `bitext` | [Bitext customer support dataset](https://huggingface.co/datasets/bitext/Bitext-customer-support-llm-chatbot-training-dataset) | CDLA-Sharing-1.0 |

Messages are lower-cased, shortened to 80 letters, and Bitext's `{{placeholders}}` are replaced
by random numbers. Records with `src` `banking77` or `bitext` keep their source's licence.

The teacher is [Laya](https://github.com/NandhaKishorM/laya) by Nandakishor M / Convai
Innovations (`convaiinnovations/laya-typed-decisions`, Apache-2.0), run through
[OpenJev](https://github.com/razorback16/openjev) (Apache-2.0). Neither project is affiliated
with this one.
