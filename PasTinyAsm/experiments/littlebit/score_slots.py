"""Score raw commands, operation choice and operation-constrained argument binding."""
from pathlib import Path
import random
import subprocess
import sys
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'classic'))
import retrieval


def main():
    executable = Path(sys.argv[1]).resolve()
    rng = random.Random(935)
    pairs = [retrieval.gen_asm.make(rng, 'sound', held=True) for _ in range(300)]
    by_operation = {}
    for words, template in retrieval.train():
        by_operation.setdefault(template[0], []).append((words, template))
    for name in sys.argv[2:]:
        model = Path(name).resolve()
        crc = zlib.crc32(model.read_bytes())
        if crc >= 2**31:
            crc -= 2**32
        outputs = subprocess.run([executable, model, str(crc)], check=True, text=True,
                                 input=''.join(q+'\n' for q, _ in pairs),
                                 capture_output=True).stdout.splitlines()
        exact = operation = bound = fixed = lost = 0
        for answer, (question, target) in zip(outputs, pairs, strict=True):
            words = answer.split()
            templates = by_operation.get(words[0], []) if words else []
            try:
                preview = retrieval.predict(question, templates)
            except ValueError:
                preview = answer
            exact += answer == target
            operation += words[:1] == target.split()[:1]
            bound += preview == target
            fixed += answer != target and preview == target
            lost += answer == target and preview != target
        print(f'{model.name}: exact {exact}/300, operation {operation}/300, '
              f'bound {bound}/300, recovered {fixed}, lost {lost}', flush=True)


if __name__ == '__main__':
    main()
