# Gemma-4 OpenAI-Compatible Docker Compose

Production-ready Docker Compose repository hosting an OpenAI-compatible API interface for `google/gemma-4-9b-4bit` model on local networks. The model persists across container re-deployments via volume-mounted cache with automatic download on first run.

## Key Features

- **OpenAI-Compatible API**: `/v1/chat/completions` and `/v1/models` endpoints
- **Model Persistence**: HuggingFace model cache mounted as Docker volume, survives container restarts
- **Auto-Download**: Model downloads on first run (~5-10 minutes depending on bandwidth), cached thereafter
- **Health Checks**: Built-in health endpoint for Portainer/Docker orchestration
- **Traefik Integration**: Reverse proxy routing with TLS termination
- **CI/CD Ready**: GitHub Actions workflow with Portainer webhook auto-deployment
- **Zero Model Weight**: Docker image contains no model weights (~0.5GB image vs ~6GB model)

## Technology Stack

- **Inference Engine**: vLLM (high-performance OpenAI API compatibility)
- **Model**: google/gemma-4-9b-4bit (~6GB VRAM, 4-bit quantization)
- **Hosting**: Docker Compose with Traefik networking
- **Deployment**: GitHub Actions → Portainer webhook
- **Volume Strategy**: HuggingFace model cache directory mounted from host

## Prerequisites

- Docker and Docker Compose installed
- ~8GB free disk space for model cache
- 8GB+ VRAM recommended (GPU optional but recommended for inference speed)
- GPU support: NVIDIA GPU + docker-nvidia-runtime (for GPU acceleration)

## Local Development

### Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/gemma4-compose.git
cd gemma4-compose
```

2. Create local configuration:
```bash
cp .env.example .env
```

Edit `.env` with your local settings (defaults work for most setups):
```
VLLM_API_PORT=8000          # vLLM service port
VLLM_MODEL=google/gemma-4-9b  # Model ID
VRAM_FRACTION=0.9           # GPU VRAM allocation (0-1)
TRAEFIK_HOST=gemma4.local   # Local domain
```

3. Start the service:
```bash
docker-compose up -d
```

On first run, the model will download (~5-10 minutes). Monitor progress:
```bash
docker-compose logs -f
```

Wait for the log message:
```
gemma4-api  | INFO:     Uvicorn running on http://0.0.0.0:8000
```

### Testing the API

Once running, test the endpoints:

**Get available models:**
```bash
curl http://localhost:8000/v1/models
```

**Health check:**
```bash
curl http://localhost:8000/health
```

**Chat completion:**
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-4-9b",
    "messages": [
      {"role": "user", "content": "Hello, tell me a short poem about Docker"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

### Model Persistence

The model is cached in your host machine's HuggingFace directory:
```bash
~/.cache/huggingface/hub
```

This directory is mounted into the container as a Docker volume. When you stop and restart the container:
- The container is removed
- The volume persists on disk
- On restart, vLLM finds the cached model and starts immediately (~1 second)
- **No re-download occurs**

To verify persistence:
```bash
docker-compose down       # Stop and remove container
docker-compose up -d      # Start again
docker-compose logs -f    # Model loads from cache (should see "Uvicorn running" in ~10s)
```

### Stopping the Service

```bash
docker-compose down
```

Model cache remains on disk for next startup.

## Production Deployment

### GitHub Actions Setup

1. Create a new GitHub repository: `gemma4-compose`

2. Initialize from local:
```bash
git remote add origin https://github.com/yourusername/gemma4-compose.git
git branch -M main
git push -u origin main
```

3. Add Portainer webhook secret:
   - In GitHub: Settings → Secrets and variables → Actions
   - New secret: `PORTAINER_WEBHOOK_URL`
   - Value: webhook URL from your Portainer stack (see Portainer Setup below)

### Portainer Stack Configuration

1. Create a new stack in Portainer

2. Set up webhook for auto-deployment:
   - Stack settings → Webhooks
   - Copy the webhook URL (format: `https://portainer.yourdomain/api/webhooks/...`)
   - Add to GitHub as `PORTAINER_WEBHOOK_URL` secret

3. Stack deployment:
   - Push changes to main branch
   - GitHub Actions workflow automatically triggers
   - Workflow creates/updates deploy branch with production configs
   - Portainer webhook receives trigger and redeploys stack
   - Zero-downtime: old model cache persists, new container starts immediately

### Traefik Integration

The vLLM service is configured to integrate with an existing Traefik reverse proxy instance.

**Prerequisites:**
- Traefik running in a Docker network named `docker` (external network)
- Traefik configured with TLS certificate resolver (if using HTTPS)

**Domain Configuration:**

In your `.env`:
```
TRAEFIK_HOST=gemma4.yourdomain.com
TRAEFIK_ENTRYPOINT=websecure    # Use 'web' for HTTP-only, 'websecure' for HTTPS
```

**How it works:**
- The vLLM container connects to the external Traefik network (`docker`)
- Traefik labels on the service advertise routing rules to Traefik
- Route: incoming requests to `https://gemma4.yourdomain.com` → Traefik → vLLM on port 8000
- TLS termination happens at Traefik, internal traffic is unencrypted
- Multiple services can use the same Traefik instance via the shared `docker` network

**Accessing via Traefik:**
```bash
curl https://gemma4.yourdomain.com/health

curl -X POST https://gemma4.yourdomain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-4-9b",
    "messages": [{"role": "user", "content": "Hello"}],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

**Network Requirements:**
- The Traefik container must be running on the `docker` network
- Create the network if it doesn't exist: `docker network create docker`
- Both vLLM and Traefik containers must be on the same network for communication

## Troubleshooting

### VRAM errors on startup
```
OutOfMemoryError: CUDA out of memory
```
- Reduce `VRAM_FRACTION` in `.env` (try 0.7 or 0.5)
- Restart container: `docker-compose down && docker-compose up -d`

### Port already in use
```
Address already in use: 0.0.0.0:8000
```
- Change `VLLM_API_PORT` in `.env` to an unused port (e.g., 8001)
- Restart: `docker-compose down && docker-compose up -d`

### Slow first-run model download
- Normal: model download takes 5-10 minutes depending on bandwidth
- Monitor: `docker-compose logs -f` to see progress
- Cache location: `~/.cache/huggingface/hub`

### Health check failed
```
Health check failed: Get "http://localhost:8000/health": dial tcp 127.0.0.1:8000: connect: connection refused
```
- vLLM is still loading the model
- Wait 1-2 minutes: `docker-compose logs -f`
- Verify port matches `VLLM_API_PORT` in docker-compose.yml

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_API_PORT` | `8000` | vLLM API server port |
| `VLLM_NCCL_TIMEOUT_S` | `600` | Model loading timeout (seconds) |
| `VLLM_MODEL` | `google/gemma-4-9b` | HuggingFace model ID |
| `VRAM_FRACTION` | `0.9` | GPU VRAM allocation (0.0-1.0) |
| `TRAEFIK_HOST` | `gemma4.local` | Traefik routing domain |
| `LOG_LEVEL` | `info` | vLLM logging level |

### Volume Mounts

```yaml
volumes:
  - ~/.cache/huggingface/hub:/root/.cache/huggingface/hub:rw
```

Model cache is shared between host and container. Changes in either location are visible in the other.

## Architecture

```
GitHub Push to main
    ↓
GitHub Actions Workflow
    ├─ Validate: docker-compose config
    ├─ Build: docker build (no model weights)
    └─ Deploy: Create deploy branch
         ↓
    Portainer Webhook
         ↓
    Portainer Stack Update
         ↓
    Docker Compose Up
         ↓
    vLLM Container Starts
    (Model loaded from cache)
         ↓
    Traefik Routes External Requests
    to https://gemma4.yourdomain.com
```

## Contributing

Contributions welcome. Please:
1. Test locally with `docker-compose up` before pushing
2. Validate configs: `docker-compose config`
3. Update README for any new features
4. Create a feature branch and submit PR to main

## License

[Your License Here]

## Support

For issues, questions, or feature requests:
- GitHub Issues: [Create an issue](https://github.com/yourusername/gemma4-compose/issues)
- Discussions: [Start a discussion](https://github.com/yourusername/gemma4-compose/discussions)
