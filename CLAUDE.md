# gemma4-compose

Production-grade Docker Compose stack for deploying vLLM with Google Gemma-4 model via OpenAI-compatible API.

## Architecture

### Service Stack
- **vLLM**: OpenAI-compatible inference server running on port 8000
- **Traefik** (external): Reverse proxy with TLS termination and dynamic Docker label routing
- **Portainer** (external): Container orchestration and deployment webhooks

### Key Integration Points

**Container Initialization**: Entrypoint chain executes `/scripts/init-model.sh` which then launches vLLM's OpenAI API server.

**Volume Mounts**:
- HuggingFace cache: `${HF_CACHE_DIR}:/root/.cache/huggingface/hub` - Shared model persistence across restarts
- Scripts directory: `./scripts:/scripts:ro` - Read-only access to initialization script

**Traefik Integration**: Docker labels on vLLM service enable dynamic reverse proxy routing and TLS certificate management.

**Health Checks**: Container includes HTTP health check against vLLM's `/health` endpoint with 5-minute startup grace period.

## Configuration Conventions

### Environment Variables

All configuration is environment-driven via `.env` file, with sensible defaults. Key variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `VLLM_MODEL` | `google/gemma-4-9b-4bit` | HuggingFace model ID to load |
| `VLLM_DTYPE` | `auto` | Model precision (auto/float16/float32) |
| `VLLM_QUANTIZATION` | `none` | Quantization method (gptq/awq/none) |
| `CUDA_VISIBLE_DEVICES` | `0` | GPU device selection (e.g., "0,1" for multi-GPU) |
| `VRAM_FRACTION` | `0.9` | Fraction of GPU VRAM to allocate to model |
| `HF_CACHE_DIR` | `$HOME/.cache/huggingface/hub` | Model cache directory on host |
| `TRAEFIK_HOST` | `gemma4.local` | Hostname for reverse proxy routing |
| `TRAEFIK_ENTRYPOINT` | `websecure` | Traefik entrypoint (web/websecure) |

Docker Compose automatically substitutes `${VAR}` syntax with environment values. For deployment, ensure `.env` file exists in compose directory with required secrets.

### Model Selection

Switch models by changing `VLLM_MODEL`:
```bash
VLLM_MODEL=google/gemma-27b  # Larger model
VLLM_MODEL=meta-llama/llama-2-13b-hf  # Different provider
```

vLLM automatically downloads and caches models from HuggingFace Hub on first run. Subsequent restarts load from cache (fast).

### Multi-GPU Configuration

For systems with multiple GPUs:
```bash
CUDA_VISIBLE_DEVICES=0,1,2,3  # Use GPUs 0, 1, 2, 3
```

Alternatively, for CPU-only operation (very slow):
```bash
CUDA_VISIBLE_DEVICES=  # Empty to use CPU
```

## Build and Test Commands

**Validate compose configuration**:
```bash
docker-compose config
```

**Start service locally**:
```bash
docker-compose up -d
```

**Monitor startup**:
```bash
docker-compose logs -f
```

**Health check**:
```bash
curl -s http://localhost:8000/health | jq
```

**Test OpenAI API endpoint**:
```bash
curl -s http://localhost:8000/v1/models | jq
```

**List available models in vLLM**:
```bash
curl -s http://localhost:8000/v1/models | jq '.data[].id'
```

## Deployment

### Local Development
```bash
# Copy and customize environment
cp .env.example .env

# Start service
docker-compose up -d

# Wait for model download and startup (~5-10 minutes first run)
watch docker-compose ps

# Test API
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-4-9b-4bit",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

### Production with Portainer
1. Configure `.env` with production values
2. GitHub Actions validates and creates `deploy` branch with only deployment files
3. Portainer webhook triggers automatic stack redeploy
4. Traefik handles TLS certificates via cert resolver (configure in Traefik host)

## Debugging

**Model download stuck**:
Check logs for download progress:
```bash
docker-compose logs -f | grep -i download
```

**Health check failing**:
If vLLM takes >5 minutes to initialize, health check may mark container unhealthy. Monitor startup:
```bash
docker-compose logs | tail -20
```

**Port conflicts**:
If port 8000 is in use, change `VLLM_API_PORT` in `.env`.

**GPU not detected**:
Verify NVIDIA Docker support:
```bash
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## Project Structure

- `docker-compose.yml` - Service definition with health checks, Traefik labels, volume mounts
- `.env.example` - Template for environment configuration (copy to `.env` for local use)
- `scripts/init-model.sh` - Container entrypoint that starts vLLM with environment variables
- `.github/workflows/deploy.yml` - CI/CD pipeline: validates config, creates deploy branch, triggers Portainer webhook
- `README.md` - User-facing documentation with API examples and setup instructions
- `docs/plans/` - Implementation planning documents

## Common Tasks

**Change model**:
Edit `.env`: `VLLM_MODEL=google/gemma-27b` then restart:
```bash
docker-compose restart vllm
```

**Allocate more VRAM**:
Edit `.env`: `VRAM_FRACTION=0.95` then restart:
```bash
docker-compose restart vllm
```

**Use multiple GPUs**:
Edit `.env`: `CUDA_VISIBLE_DEVICES=0,1` then restart:
```bash
docker-compose restart vllm
```

**Check model cache size**:
```bash
du -sh ~/.cache/huggingface/hub
```
