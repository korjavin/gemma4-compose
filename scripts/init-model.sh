#!/bin/bash
set -e

MODEL_ID="${VLLM_MODEL:-google/gemma-4-9b}"
MODEL_CACHE_DIR="/root/.cache/huggingface/hub"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Init script starting..."

if [ -d "$MODEL_CACHE_DIR/models--google--gemma-4-9b" ] || [ -d "$MODEL_CACHE_DIR/models--google--gemma-4" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Model cache found at $MODEL_CACHE_DIR, starting vLLM immediately..."
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Model cache not found, will download during vLLM startup..."
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting vLLM server..."

exec python -m vllm.entrypoints.openai.api_server \
    --model "${VLLM_MODEL:-google/gemma-4-9b}" \
    --dtype float16 \
    --quantization gptq \
    --max-model-len 4096 \
    --host 0.0.0.0 \
    --port 8000
