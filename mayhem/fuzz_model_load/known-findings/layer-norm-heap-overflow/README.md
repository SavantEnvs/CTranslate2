# Heap-buffer-overflow read in `cpu::layer_norm`

- Found by: `fuzz_model_load` (`reproducer.bin`; run `/mayhem/fuzz_model_load-standalone reproducer.bin`).
- Cause: `src/cpu/kernels.cc:492` reads `gamma`/`beta` for the full model depth, but a crafted model can ship shorter vectors.
- Impact: out-of-bounds heap read when translating with a crafted model.
- Fix: validate `gamma`/`beta` sizes against the input depth in `LayerNorm::operator()`.
