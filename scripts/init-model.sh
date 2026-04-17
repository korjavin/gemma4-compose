#!/bin/bash
set -e

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting vLLM server..."

exec python -m vllm.entrypoints.openai.api_server \
    --model "${VLLM_MODEL:-google/gemma-4-9b}" \
    --dtype "${VLLM_DTYPE:-auto}" \
    --quantization "${VLLM_QUANTIZATION:-gptq}" \
    --max-model-len 4096 \
    --host 0.0.0.0 \
    --port "${VLLM_API_PORT:-8000}"
