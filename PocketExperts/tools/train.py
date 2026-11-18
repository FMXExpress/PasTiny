"""Fit final RMS gains on an approved specialist corpus using greedy inference."""
import argparse
import hashlib
import json
import struct
import tempfile
import zlib
from pathlib import Path
from evaluate import corpus,evaluate
from package import field

def main():
    p=argparse.ArgumentParser()
    for arg in ["exe","base","train","validation","output"]:
        p.add_argument(arg,type=Path)
    p.add_argument("--coordinates",type=int,default=96,choices=range(1,97),metavar="1..96")
    args=p.parse_args()
    train_meta,train=corpus(args.train)
    val_meta,val=corpus(args.validation)
    if train_meta["split"]!="train" or val_meta["split"]!="validation" or not train or not val:
        raise ValueError("supply nonempty training and validation splits")
    if {r["question"].casefold() for r in train} & {r["question"].casefold() for r in val}:
        raise ValueError("overlapping splits")
    ids={r["expert"] for r in train+val}
    if len(ids)!=1: raise ValueError("one specialist per fit")
    ident=ids.pop()
    original=args.base.read_bytes()
    if len(original)!=381808 or original[:12]!=struct.pack("<4s4H",b"TNY2",96,4,4,256):
        raise ValueError("invalid baseline")
    with tempfile.TemporaryDirectory() as tmp:
        runtime=Path(tmp)
        def score(model,rows):
            (runtime/"MODEL.BIN").write_bytes(model)
            (runtime/"EXPERTS.CAT").write_bytes(b"PEC1"+bytes([1,ident])+field("MODEL.BIN",12)+
                field("Candidate",28)+field("",20)+struct.pack("<I",zlib.crc32(model)))
            result=evaluate(args.exe.resolve(),runtime,rows,"oracle")
            return sum(r["exact"] for r in result),sum(r["similarity"] for r in result)
        best=original
        training_score=score(best,train)
        for i in range(args.coordinates):
            offset=len(best)-384+4*i
            start=best
            gain=struct.unpack_from("<f",start,offset)[0]
            for factor in (0.9,1.1):
                candidate=bytearray(start)
                struct.pack_into("<f",candidate,offset,gain*factor)
                quality=score(candidate,train)
                if quality>training_score:
                    training_score,best=quality,bytes(candidate)
        baseline=score(original,val)
        fitted=score(best,val)
        report=dict(train=train_meta,validation=val_meta,baseline_validation=baseline,
                    fitted_validation=fitted,train_score=training_score,coordinates=args.coordinates,
                    base_sha256=hashlib.sha256(original).hexdigest())
        if fitted>baseline:
            with args.output.open("xb") as f: f.write(best)
            report["export_sha256"]=hashlib.sha256(best).hexdigest()
        print(json.dumps(report,indent=2))
if __name__=="__main__": main()
