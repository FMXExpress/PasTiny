"""Check the exact-answer tools (TOOLS.PAS) through a native FPC build of EXPERT.

  python3 tests/test_tools.py ./EXPERT

Uses the expanded FLOPPY3 fixture, like test_runtime.py.  Every question in
ANSWERS must be answered by a tool with exactly the text given; every question
in LEAVE must go to a model; and with the tools off nothing is answered by one.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ANSWERS = [
    ("what is 458 plus 367", "458 plus 367 is 825."),
    ("What is 7 x 8?", "7 times 8 is 56."),
    ("twenty add seventeen", "20 plus 17 is 37."),
    ("subtract 3 from 10", "10 minus 3 is 7."),
    ("what is 3 minus 10", "3 minus 10 is -7."),
    ("divide 17 by 5", "17 divided by 5 is 3 remainder 2."),
    ("what is 99999 times 99999", "That number is too big for me."),   # does not fit in 32 bits
    ("please tell me what is one more than 9?", "1 more than 9 is 10."),
    ("what is 3 less than 10", "3 less than 10 is 7."),
    ("is 5 more than 3", "Yes, 5 is more than 3."),
    ("is 842 bigger than 837", "Yes, 842 is bigger than 837."),
    ("which is smaller 100 or 99", "99 is smaller."),
    ("What number comes after 842?", "843 comes after 842."),
    ("What is double seventeen", "Double 17 is 34."),
    ("what is half of 45", "Half of 45 is 22 and a half."),
    ("13 squared", "13 squared is 169."),
    ("what is the square root of 169?", "The square root of 169 is 13."),
    ("what is the square root of 170", None),
    ("count down from 5 to 3?", "5, 4, 3."),
    ("write 100 in words?", "One hundred."),
    ("what is 1234 in words", "One thousand two hundred and thirty-four."),
    ("SPELL THE NUMBER 98?", "Ninety-eight."),
    ("Write sixty-one in numbers", "61."),
    ("roman numeral for 1986", "1986 is MCMLXXXVI in Roman numerals."),
    ("what does xix mean in roman numerals", "XIX is 19."),
    ("MCMIV IN NUMBERS?", "MCMIV is 1904."),
    ("what is IIII in roman numerals", None),       # not a properly written numeral
    ("reverse jumped", "depmuj"),
    ("how many letters in jumped", "Jumped has 6 letters."),
    ("which letter does rise begin with", "Rise starts with R."),
    ("what letter does in end with?", "In ends with N."),
    ("How do you spell laugh?", "L-A-U-G-H."),
    ("make knives uppercase?", "KNIVES."),
    ("what comes before r in the alphabet?", "Q comes before R."),
    ("which letter of the alphabet is c?", "C is letter number 3."),
]
LEAVE = [
    "what is the capital of peru",
    "what are the capitals of belgium and russia",
    "i did mix it",
    "what comes after monday",
    "how do you spell",
    "what is a civil war",
    "who wrote hamlet",
    "is chad landlocked",
]

exe = Path(sys.argv[1]).resolve()
root = Path(__file__).resolve().parents[1]


def answers(dest, lines):
    """[(answer text, answered by a tool)] for each question line."""
    out = subprocess.run([exe], input="\n".join(lines) + "\nquit\n", text=True,
                         capture_output=True, cwd=dest).stdout.splitlines()
    return [(out[i - 1], line.endswith(" tool")) for i, line in enumerate(out)
            if line.startswith("answer ms=")]


with tempfile.TemporaryDirectory() as tmp:
    dest = Path(tmp) / "runtime"
    shutil.copytree(root / "dist/FLOPPY3", dest)
    got = answers(dest, ["tools on"] + [q for q, _ in ANSWERS])
    assert len(got) == len(ANSWERS), (len(got), len(ANSWERS))
    for (q, want), (text, tool) in zip(ANSWERS, got):
        if want is None:
            assert not tool, (q, text)
        else:
            assert tool and text == want, (q, text, want)
    got = answers(dest, ["tools on"] + LEAVE)
    assert len(got) == len(LEAVE) and not any(tool for _, tool in got), got
    got = answers(dest, [q for q, _ in ANSWERS])        # redirected input: tools start off
    assert len(got) == len(ANSWERS) and not any(tool for _, tool in got), got
    got = answers(dest, ["tools on", "tools off", "what is 458 plus 367"])
    assert len(got) == 1 and not got[0][1], got
print("Tools: %d exact answers, %d questions left to the models, off by default for redirected input."
      % (sum(1 for _, w in ANSWERS if w), len(LEAVE) + sum(1 for _, w in ANSWERS if not w)))
