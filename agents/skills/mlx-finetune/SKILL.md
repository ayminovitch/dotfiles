---
name: mlx-finetune
description: Fine-tune a small open model on an Apple Silicon Mac with Apple's MLX (LoRA / QLoRA) — decide if fine-tuning is the right tool, prepare chat-format data, train within the Mac's memory, compare against the base model with evals, and serve the result (MLX server or Ollama). Use when the user wants to fine-tune, adapt or train a model locally.
---

# Fine-tune locally with MLX (LoRA)

MLX is Apple's machine-learning framework for Apple Silicon; `mlx-lm` adds LoRA fine-tuning for
open models. It runs on the Mac itself (not in Docker). Check the memory first
(`sysctl -n hw.memsize`). With 16 GB, use **4-bit models of roughly 4B parameters or less** and
quit Ollama/Docker while training; with 32 GB or more, 7-8B models fit.

## 0. Should you fine-tune at all?

Fine-tuning changes **behavior and format** (tone, a fixed output structure, a narrow
classification or extraction task, shorter prompts, a small model doing one job well). It is a
poor way to add **knowledge** that changes — use RAG for that. Try a strong prompt +
few-shot examples first; fine-tune only if evals show prompting can't reach the bar or a
smaller/cheaper model is needed. Say this to the user before starting.

## 1. Data (the part that decides quality)

- Chat format, one example per line, in `data/train.jsonl`, `data/valid.jsonl`,
  `data/test.jsonl` (roughly 80/10/10, no overlap, test set never trained on):
  ```json
  {"messages": [{"role": "system", "content": "..."}, {"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]}
  ```
- Hundreds of clean, consistent examples beat thousands of noisy ones. Remove duplicates,
  personal data and secrets. Keep examples short; long ones cost the most memory.
- Write a small script that validates every line (valid JSON, roles in order, non-empty).

## 2. Train

```bash
uv tool install mlx-lm          # adds mlx_lm.lora, mlx_lm.fuse, mlx_lm.generate, mlx_lm.server
mlx_lm.lora --model <hf-model-id> --train --data ./data \
  --iters 600 --batch-size 1 --num-layers 8 --grad-checkpoint --mask-prompt \
  --adapter-path ./adapters --steps-per-eval 100 --save-every 100
```

- `<hf-model-id>`: a 4-bit instruct model from huggingface.co/mlx-community, ~1–4B parameters
  (check the model's license allows your use).
- `--mask-prompt` trains only on the assistant replies. `--batch-size 1`, fewer
  `--num-layers` and `--grad-checkpoint` keep memory down; add
  `--grad-accumulation-steps 4` for a larger effective batch.
- Watch validation loss: if it rises while training loss falls, it's overfitting — stop
  earlier (fewer `--iters`) or add data.

## 3. Measure (base vs fine-tuned)

```bash
mlx_lm.lora --model <hf-model-id> --adapter-path ./adapters --data ./data --test   # test loss
mlx_lm.generate --model <hf-model-id> --adapter-path ./adapters --prompt "..."     # spot check
```

Loss alone isn't quality. Serve both and run the same eval set (`llm-evals` skill):

```bash
mlx_lm.server --model <hf-model-id> --adapter-path ./adapters --port 8080   # OpenAI-compatible
```

```python
litellm.completion(model="openai/local", api_base="http://127.0.0.1:8080/v1",
                   api_key="local", messages=[...])
```

Ship only if the fine-tuned model beats the base model (and a well-prompted bigger model, if
that's the alternative) on the eval set.

## 4. Use it

- **Simplest:** keep serving with `mlx_lm.server --adapter-path ./adapters`.
- **Single model folder:** `mlx_lm.fuse --model <hf-model-id> --adapter-path ./adapters
  --save-path ./fused_model`.
- **In Ollama:** fuse with `--dequantize` (Ollama imports full-precision safetensors), then
  a `Modelfile` containing `FROM ./fused_model` and
  `ollama create <name> --quantize q4_K_M` (run `ollama create --help` to see the quantization
  levels your version supports; not every architecture imports — if it fails, use the MLX server).

## Keep it reproducible

Commit the data-prep script, the exact command (or an `mlx_lm.lora --config` YAML), the base
model id, the eval results and a short model card (purpose, data, limits). Don't commit
weights (`*.safetensors` is already git-ignored).
