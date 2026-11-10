# Heap-buffer-overflow read in `cpu::dequantize_gemm_output_row`

- Found by: `fuzz_model_load` (`reproducer.bin`; run `/mayhem/fuzz_model_load-standalone reproducer.bin`).
- Cause: `src/cpu/kernels.cc:673` indexes the bias/scale vectors by output column; a model whose bias or scale shape disagrees with the weight shape makes it read past the buffer.
- Impact: out-of-bounds heap read when translating with a crafted model.
- Fix: check the bias and scale sizes against the weight's output dimension when the layer is built.
