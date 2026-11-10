# Division by zero when `num_heads` is 0

- Found by: `fuzz_model_load` (`reproducer.bin`, a mutated v2 i16 model; run `/mayhem/fuzz_model_load-standalone reproducer.bin`).
- Cause: `src/layers/attention_layer.cc:126` computes `_d_model / _num_heads`; the `num_heads` attribute is read from the model file and never validated.
- Impact: a crafted model file crashes the process (SIGFPE) at load time.
- Fix: reject `num_heads == 0` (and `d_model % num_heads != 0`) before the division.
