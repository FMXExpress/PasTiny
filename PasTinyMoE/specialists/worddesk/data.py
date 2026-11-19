"""Generate three deliberately bounded word-desk syllabi. All strings are ASCII."""
from pathlib import Path
import json
root=Path(__file__).resolve().parent
groups={
"SPELL":([
 ("recieve","receive"),("seperate","separate"),("definately","definitely"),("untill","until"),
 ("freind","friend"),("becuase","because")],
 ["correct the spelling of {}","spell {} correctly","fix the misspelling {}","how should i spell {}",
  "what is the correct spelling for {}","i wrote {} how is it spelled","correct this word {}","spelling help for {}",
  "is {} spelled right give the correct word","rewrite {} with correct spelling"],
 ["what should i write instead of {}","my note says {} can you fix its spelling"]),
"CONFUSE":([
 ("affect","Usually a verb meaning influence."),("effect","Usually a noun meaning result."),
 ("stationary","Not moving."),("stationery","Writing materials."),
 ("complement","Something that completes."),("compliment","An expression of praise.")],
 ["in a confusing pair what does {} mean","meaning of {} in a word pair","what is the usual meaning of {}",
  "explain the word {}","help me remember {}","define {}","how is {} used","word choice what does {} mean",
  "tell me about the word {}","which meaning belongs to {}"],
 ["i mix these words up what does {} stand for","give the everyday sense of {}"]),
"GRAMMAR":([
 ("noun","Names a person, place, thing or idea."),("verb","Expresses an action or state."),
 ("adjective","Describes a noun."),("adverb","Modifies a verb, adjective or another adverb."),
 ("pronoun","Can stand in for a noun phrase."),("conjunction","Joins words, phrases or clauses.")],
 ["what is a {}","define {}","what does a {} do","explain the term {}","grammar meaning of {}",
  "what is the job of a {}","describe a {}","what role does a {} have","tell me about the {}",
  "in grammar what is a {}"],
 ["what function does the term {} describe","give a short grammar lesson about the {}"])}
for name,(facts,training,testing) in groups.items():
 for split,templates in [('train',training),('heldout',testing)]:
  rows=[dict(question=t.format(term),answer=answer,fact=term) for term,answer in facts for t in templates]
  (root/f'{name}-{split}.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
