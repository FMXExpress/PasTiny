# 079 Map Reader

Defines six map-reading terms. Covers legends, scale, contour lines, latitude, longitude, and the latitude of the equator.

The corpus contains 15 training examples and two held-out questions for each fact. The evaluation checks recall across wording changes.

## References

- [USGS topographic maps](https://www.usgs.gov/programs/national-geospatial-program/topographic-maps)
- [National Geographic, Map](https://education.nationalgeographic.org/resource/map/)
- [NOAA, Latitude and Longitude](https://oceanservice.noaa.gov/facts/latitude.html)

## Training

Run from PasTinyMoE with WebTiny's training dependencies installed. Set WEBTINY to a checkout of revision `a1a36720ed558d6998e5beed9d4dbdd792626056`.

```sh
d=specialists/batch50/079
OPENBLAS_NUM_THREADS=1 python "$WEBTINY/training/train.py" --init TINY.BIN \
  --data "$d/train.jsonl" --steps 450 --threads 1 --batch-size 8 \
  --lr .00035 --seed 42 --out "$d/model.bin"
```

The WebTiny CPU decoder matched 9 of 12 held-out answers exactly.
