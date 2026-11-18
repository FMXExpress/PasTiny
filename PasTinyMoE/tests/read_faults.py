"""Linux host fault injection. Requires strace and a native Free Pascal build."""
from pathlib import Path
import subprocess
import sys
import tempfile

exe, runtime = [Path(arg).resolve() for arg in sys.argv[1:]]
commands = "use 2\nquit\n"
with tempfile.TemporaryDirectory() as tmp:
    trace = Path(tmp) / "reads.log"

    def run(fault=None):
        args = ["strace", "-qq", "-yy", "-e", "trace=read", "-o", str(trace)]
        if fault:
            args.extend(["-e", "inject=read:error=EIO:when="+fault])
        return subprocess.run(args+[exe], cwd=runtime, input=commands, text=True,
                              capture_output=True, check=True).stdout

    run()
    reads = trace.read_text().splitlines()
    start = next(i for i,line in enumerate(reads,1) if "/E002.BIN>" in line)
    damaged = start+2
    restored = run(str(damaged))
    assert "load failed E002.BIN read failure" in restored and restored.count("active 1 ")==2, restored
    unloaded = run(f"{damaged}+1")
    assert "recovery failed read failure" in unloaded and "unloaded" in unloaded, unloaded
    print(restored, unloaded, sep="\n")
