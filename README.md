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

### Prerequisites

Before deploying to production, ensure you have:

- **Portainer Instance**: A running Portainer server with webhook support enabled
- **GitHub Personal Access Token**: Token with `repo` scope for the repository
- **Traefik Setup**: Existing Traefik reverse proxy on a Docker network named `docker`
- **Domain Name**: A registered domain for your API (e.g., `gemma4.yourdomain.com`)
- **TLS/SSL Certificates**: Traefik configured with a certificate resolver (Let's Encrypt or manual certs)
- **GitHub Repository**: Initialized and pushed with this codebase

### Deployment Steps

#### Step 1: Create GitHub Repository

Create a new GitHub repository and push the codebase:

```bash
git remote add origin https://github.com/yourusername/gemma4-compose.git
git branch -M main
git push -u origin main
```

#### Step 2: Configure GitHub Secrets

Add the Portainer webhook URL to GitHub:

1. In GitHub: Settings → Secrets and variables → Actions
2. New secret: `PORTAINER_WEBHOOK_URL`
3. Value: Webhook URL from your Portainer stack (see Portainer Setup below)

#### Step 3: Set Up Portainer Stack

1. Log into Portainer
2. Create a new stack:
   - Choose "Git repository"
   - Repository URL: `https://github.com/yourusername/gemma4-compose.git`
   - Compose file path: `docker-compose.yml`
   - Branch: `deploy` (GitHub Actions creates this automatically)
3. Enable webhooks:
   - Stack settings → Webhooks → Enable
   - Copy the webhook URL
   - Add this URL to GitHub as `PORTAINER_WEBHOOK_URL` secret

#### Step 4: Deploy

Push changes to the main branch to trigger automatic deployment:

```bash
git push origin main
```

**What happens automatically:**
1. GitHub Actions workflow validates the docker-compose configuration
2. Creates/updates the `deploy` branch with production settings
3. Sends webhook notification to Portainer
4. Portainer pulls the `deploy` branch and updates the stack
5. vLLM container restarts with model cache persisting (no re-download)
6. Traefik routes traffic to the new container

#### How the Workflow Works

The GitHub Actions workflow (`.github/workflows/deploy.yml`) automates the entire pipeline:

1. **Trigger**: Pushes to `main` or `master` branch (doc-only changes are skipped)
2. **Validate**: Runs `docker-compose config` to check YAML syntax and service dependencies
3. **Deploy**: Creates/updates a `deploy` branch with production configurations
4. **Webhook**: Sends POST request to your Portainer webhook URL, triggering stack redeploy
5. **Result**: Portainer pulls the `deploy` branch and redeploys the stack automatically

### Environment Variable Customization

Configure production behavior by editing `.env` before deploying:

```env
# API Port (usually internal, exposed via Traefik)
VLLM_API_PORT=8000

# Model selection (change for different versions)
VLLM_MODEL=google/gemma-4-9b

# GPU VRAM allocation (adjust for your hardware)
VRAM_FRACTION=0.9

# Model loading timeout
VLLM_NCCL_TIMEOUT_S=600

# Production domain for Traefik
TRAEFIK_HOST=gemma4.yourdomain.com

# TLS entrypoint (use 'websecure' for HTTPS)
TRAEFIK_ENTRYPOINT=websecure

# Logging level
LOG_LEVEL=info
```

After changing `.env`, commit and push to trigger redeployment:

```bash
git add .env
git commit -m "config: update production settings"
git push origin main
```

### Traefik Integration & SSL/TLS Setup

The vLLM service integrates with an existing Traefik reverse proxy for routing and TLS termination.

**Prerequisites:**
- Traefik running in Docker on a network named `docker` (external network)
- Traefik configured with a TLS certificate resolver for HTTPS
- Domain pointing to your Traefik instance (DNS A record)

**Certificate Resolver Configuration:**

In your Traefik configuration, ensure a certificate resolver is configured. Example with Let's Encrypt:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /var/lib/traefik/acme.json
      httpChallenge:
        entryPoint: web
```

**vLLM Traefik Labels:**

The docker-compose.yml includes Traefik labels that enable automatic routing:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.gemma4.rule=Host(`${TRAEFIK_HOST}`)
  - traefik.http.routers.gemma4.entrypoints=${TRAEFIK_ENTRYPOINT}
  - traefik.http.routers.gemma4.tls.certresolver=letsencrypt
  - traefik.http.services.gemma4.loadbalancer.server.port=8000
```

**Network Requirements:**
- Create the Traefik network if it doesn't exist: `docker network create docker`
- Both vLLM and Traefik containers must be on the same network
- Traefik listens on ports 80 (HTTP) and 443 (HTTPS) externally
- Internal traffic between Traefik and vLLM is unencrypted

**Testing Your Production Deployment:**

Once deployed, verify the API is accessible through Traefik:

```bash
# Health check
curl https://gemma4.yourdomain.com/health

# Get models
curl https://gemma4.yourdomain.com/v1/models

# Chat completion
curl -X POST https://gemma4.yourdomain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-4-9b",
    "messages": [{"role": "user", "content": "Hello"}],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

### Rolling Updates & Zero-Downtime Redeployments

The deployment pipeline ensures model cache persistence during updates:

1. **Model Cache**: Stored in Docker volume at `~/.cache/huggingface/hub` on host
2. **Volume Persistence**: Cache survives container restart and removal
3. **Zero-Downtime**: Old container stops → new container starts with cached model → no re-download
4. **Deployment Flow**: 
   - Old container serving requests
   - New container pulls cache (< 1 second load time)
   - Traefik routes new requests to new container
   - Old container stops after graceful shutdown

**Updating the Model Version:**

To switch to a different Gemma version or model:

1. Edit `.env` and change `VLLM_MODEL`:
```env
VLLM_MODEL=google/gemma-27b    # or any other HuggingFace model ID
```

2. Commit and push:
```bash
git add .env
git commit -m "config: update to gemma-27b"
git push origin main
```

3. GitHub Actions triggers deployment → old model cached, new model downloaded on first run
4. First request to new model takes longer (~5-10 min), subsequent requests are fast

**Cache Management:**

Model cache can grow large (~6GB per model). To free space:

- In Portainer: Stack settings → Volumes → remove specific volume
- Or manually on host: `rm -rf ~/.cache/huggingface/hub`
- Next deployment will re-download the model

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

MIT License - See LICENSE file for details

## Support

For issues, questions, or feature requests:
- GitHub Issues: [Create an issue](https://github.com/yourusername/gemma4-compose/issues)
- Discussions: [Start a discussion](https://github.com/yourusername/gemma4-compose/discussions)
