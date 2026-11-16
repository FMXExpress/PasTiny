"""Compare rejection messages and status against the unmodified C loader."""
from pathlib import Path
import subprocess
import tempfile
import struct
root = Path(__file__).resolve().parent.parent
model = (root / 'TINY.BIN').read_bytes()
cases = {'empty': b'', 'magic': b'NOPE' + model[4:],
         'header': model[:8], 'truncated': model[:-1], 'extra': model + b'!',
         'dimension': model[:4] + struct.pack('<H', 129) + model[6:]}
for label, data in cases.items():
    with tempfile.TemporaryDirectory() as tmp:
        Path(tmp, 'TINY.BIN').write_bytes(data)
        expected = None
        for binary in ('build/reference/tiny_ref', 'build/int/TINY', 'build/float/TINY', 'build/debug/TINY'):
            result = subprocess.run([str(root / binary), '0', '/P'], cwd=tmp,
                                    input='', capture_output=True, text=True)
            assert result.returncode == 1, (label, binary, result)
            message = result.stdout.split('TINY: ')[-1].strip()
            if expected is None:
                expected = message
            assert message == expected, (label, binary, message, expected)
        print(f'{label}: C/Pascal rejection matches')
