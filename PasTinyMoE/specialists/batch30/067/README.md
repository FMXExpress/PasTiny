# 067 · Light

This elementary optics expert covers reflection, refraction at oblique incidence, absorption, dispersion through a prism, wavelength and frequency. Its dispersion example is the familiar separation of colors in white light. The refraction example describes a ray whose direction changes at a boundary. Normal incidence can change the speed without changing direction.

The concepts follow [OpenStax College Physics 2e](https://openstax.org/details/books/college-physics-2e), especially the chapters on waves, electromagnetic radiation and geometric optics. Short labels and questions were written for the pilot. Ninety development questions cover six concepts. Eighteen prompts, including six individually written questions, were frozen before training. All terms are represented during training.

Use WebTiny trainer a1a36720ed558d6998e5beed9d4dbdd792626056 and CPU PyTorch 2.15.0. From PasTinyMoE:

```sh
python "$WEBTINY/training/train.py" --init TINY.BIN --data specialists/batch30/067/train.jsonl \
  --steps 650 --batch-size 8 --threads 1 --lr .00035 --out build/067/model.bin
```
