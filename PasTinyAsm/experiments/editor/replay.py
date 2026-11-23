"""Convert an existing editor program into BIOS keystrokes for an empty session."""
from pathlib import Path
import sys
project, runtime, game = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
source = (project / 'examples' / f'{game}.SRC').read_text().splitlines()
keys = bytearray()
def enter(text):
    keys.extend(text.encode('ascii') + b'\r')
enter('name ' + ('TABGO' if game == 'GOGAME' else 'TABCHESS'))
enter('say welcome to ' + ('go' if game == 'GOGAME' else 'chess'))
for line in source:
    if line in ('NEXT', 'END'):
        keys.append(9)
    elif ':' not in line and line.split()[0] in ('FOR', 'IF', 'FOREVER'):
        enter(line + ':')
    elif line.endswith('ECHO .5'):
        enter(line[:-8])
        enter('print ".5"')
        enter('NL')
    elif line.startswith('ECHO ') and ':' not in line:
        enter('print "' + line[5:] + '"')
        enter('NL')
    else:
        # A period in an unquoted command is an editor sentence separator.
        enter(line.replace('PRINT .:', 'NUMBER 0:')
              .replace('in check.', 'in check'))
enter('quit')
(runtime / 'KEYS.IN').write_bytes(keys)
print(len(keys), keys.count(9), keys.count(13))
