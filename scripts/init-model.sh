#!/bin/bash
set -e

if ! command -v python &> /dev/null; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: Python not found in container"
  exit 1
fi

python -c "import vllm" 2>/dev/null || {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: vLLM not installed in container"
  exit 1
}

CACHE_DIR="/root/.cache/huggingface/hub"

if [ -d "$CACHE_DIR" ] && [ "$(ls -A "$CACHE_DIR")" ]; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Model cache found, starting vLLM..."
else
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Downloading model..."
fi

exec python -m vllm.entrypoints.openai.api_server \
    --model "${VLLM_MODEL:-google/gemma-4-9b-4bit}" \
    --dtype "${VLLM_DTYPE:-auto}" \
    --quantization "${VLLM_QUANTIZATION:-none}" \
    --gpu-memory-utilization "${VRAM_FRACTION:-0.9}" \
    --max-model-len 8192 \
    --host 0.0.0.0 \
    --port "${VLLM_API_PORT:-8000}"

