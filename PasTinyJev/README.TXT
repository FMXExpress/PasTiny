PasTinyJev 1.0 - typed decisions on a 386
==========================================
Give JEV a state (a short message) and typed questions about it. It
answers with probabilities read from a TINY 2.1 network. It writes no
text, so an answer is always one of the options you gave.

Files: JEV.EXE, EXPERTS.CAT, TRIAGE.BIN, GENERAL.BIN. Keep them in one
directory. Needs a 386 and about 570 KB of free conventional memory.
A coprocessor is optional.

  C:\JEV> JEV                  type commands
  C:\JEV> JEV < DEMO.IN        run the examples

Commands (upper or lower case)
  STATE text
  NOUL id | instructions
  CHOICE id | instructions | name=description ; name=description
  SCORE id | instructions | level ; level ; level
  ASK question          text answer from the general model
  LIST                  models in the catalog
  USE id                use one model for everything
  AUTO                  pick the model per command (the default)
  MEM                   free memory
  QUIT

Example
  STATE Everything is down and we have a demo at noon.
  NOUL urgent | Does the customer need a reply within the hour?
  CHOICE team | Which team? | outage=service down ; billing=charges
  SCORE tone | How upset is the customer? | calm ; annoyed ; furious

Answers look like this
  urgent noul=0.6720            probability of yes
  team choice=outage confidence=0.4602 outage=0.8169 billing=0.0617
  tone score=0.2011 confidence=0.5206 0=0.8441 1=0.1106 2=0.0453

  score is the expected level, counted from 0. confidence is 1 when
  the model is certain and 0 when every option is equally likely.
  ms= is the time taken.

Limits
  A state keeps 80 letters: the first 53 and the last 26 of a longer
  one. State, instructions and the longest option must fit in 127
  letters together; otherwise the answer is "error=too long by N".
  A command line holds 255 letters and 24 options.

  TRIAGE.BIN knows short customer-support and banking messages:
  topic, tone, urgency and the like. It learned from a larger model
  (Laya, through OpenJev) and agrees with it on about 4 new messages
  in 5. It can be very sure and still wrong, so do not read a high
  confidence as proof. It is not a general reasoner.

Escape cancels a question at the keyboard.
See README.md in the source for training, tests and measurements.
