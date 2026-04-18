# Gemma-4 OpenAI-Compatible Docker Compose with Ollama

Production-ready Docker Compose repository hosting an OpenAI-compatible API interface for Gemma (and other models) using Ollama on local networks. The model persists across container re-deployments via volume-mounted cache with automatic download on first run.

## Key Features

- **OpenAI-Compatible API**: Ollama's `/v1/chat/completions` and `/v1/models` endpoints
- **Model Flexibility**: Run any Ollama model (Gemma, Llama, Mistral, etc.)
- **Model Persistence**: Ollama model cache mounted as Docker volume, survives container restarts
- **Auto-Download**: Model downloads on first run, cached thereafter
- **Health Checks**: Built-in health endpoint for Portainer/Docker orchestration
- **Traefik Integration**: Reverse proxy routing with TLS termination
- **CI/CD Ready**: GitHub Actions workflow with Portainer webhook auto-deployment
- **Lightweight**: Ollama image is ~1GB (vs 10GB+ for other inference engines)

## Technology Stack

- **Inference Engine**: Ollama (lightweight, OpenAI API compatible)
- **Models**: Gemma (7b, 2b), Llama2, Mistral, and 100+ others
- **Device**: CPU or GPU (auto-detects available hardware)
- **Hosting**: Docker Compose with Traefik networking
- **Deployment**: GitHub Actions → Portainer webhook
- **Volume Strategy**: Ollama model cache mounted from host

## Prerequisites

- Docker and Docker Compose installed
- ~15GB free disk space for model cache (depends on model size)
- 4+ CPU cores and 8GB+ RAM (for CPU inference)
- Optional: NVIDIA GPU for faster inference

## Performance Estimates

- **Gemma 7B on CPU**: ~2-5 tokens/sec
- **Gemma 7B on GPU (8GB VRAM)**: ~20-50 tokens/sec
- **Gemma 2B on CPU**: ~5-10 tokens/sec

## Quick Start (Local Development)

```bash
# Clone and configure
git clone https://github.com/korjavin/gemma4-compose.git
cd gemma4-compose
cp .env.example .env

# Edit .env if needed (model name, port, etc.)
# OLLAMA_MODEL=gemma4:e2b

# Start container (first run downloads model)
docker-compose up -d

# Wait for model download and startup
docker-compose logs -f ollama

# Test the API
curl http://localhost:11434/api/tags

# Chat completion
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:e2b",
    "messages": [{"role": "user", "content": "hello"}],
    "stream": false
  }'

# Stop
docker-compose down
```

## Production Deployment (Portainer)

1. Create the model cache directory on your additional disk:
   ```bash
   sudo mkdir -p /mnt/HC_Volume_105196246/ollama_cache
   sudo chmod 777 /mnt/HC_Volume_105196246/ollama_cache
   ```

2. In Portainer → New Stack:
   - Source: GitHub (point to this repo)
   - Branch: `deploy`
   - Environment variables:
     ```
     OLLAMA_MODEL=gemma4:e2b
     MODEL_CACHE_PATH=/mnt/HC_Volume_105196246/ollama_cache
     TRAEFIK_HOST=gemma4.yourdomain.com
     ```

3. Deploy → Model auto-downloads on first run

## Model Persistence

The model cache persists via Docker volume:
- **First run:** Model downloads from Ollama registry (~2-7GB depending on model)
- **Subsequent runs:** Load from cache (<1 sec)
- **Re-deployment:** Container stops/restarts, cache volume survives → no re-download

Volume mount: `${MODEL_CACHE_PATH}:/root/.ollama`

## Configuration

Edit `.env` to customize:

```bash
OLLAMA_MODEL=gemma4:e2b            # Model name (Ollama format)
OLLAMA_API_PORT=11434              # API port
OLLAMA_KEEP_ALIVE=5m               # Keep model in memory after request
MODEL_CACHE_PATH=/mnt/...          # Where to store models
TRAEFIK_HOST=gemma4.local          # Domain for Traefik routing
```

## Available Models

Popular models in Ollama format:
- `gemma4:e2b` - Google Gemma 4 E2B, multimodal edge model (~2GB)
- `gemma4:e4b` - Google Gemma 4 E4B, multimodal edge model (~4GB)
- `gemma4:26b` - Google Gemma 4 26B MoE (A4B active)
- `gemma4:31b` - Google Gemma 4 31B dense
- `llama2:7b` - Meta Llama2 7B (3.8GB)
- `mistral:7b` - Mistral 7B (4.1GB)

See all models: [ollama.ai/library](https://ollama.ai/library)

## API Examples

All endpoints follow OpenAI API format:

**List Models:**
```bash
curl http://localhost:11434/api/tags
```

**Chat Completion:**
```bash
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:e2b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is 2+2?"}
    ],
    "stream": false
  }'
```

**Streaming Response:**
```bash
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:e2b",
    "messages": [{"role": "user", "content": "hello"}],
    "stream": true
  }'
```

## Troubleshooting

**"Model not found":**
- Check model name format: `ollama pull gemma4:e2b`
- Available models: `curl http://localhost:11434/api/tags`

**"Out of memory":**
- Reduce model size: use smaller variant (e.g., `gemma4:e2b` instead of `gemma4:e4b`)
- Increase `OLLAMA_KEEP_ALIVE` to keep model in memory

**"Slow inference on CPU":**
- This is expected for CPU inference
- Consider adding GPU if available
- Use smaller model (2B instead of 7B)

**Port conflict:**
- Change `OLLAMA_API_PORT` in `.env`
- Update Traefik labels if using reverse proxy

## License

MIT
