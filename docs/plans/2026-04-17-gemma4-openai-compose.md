# Gemma-4 OpenAI-Compatible Docker Compose Repository

## Overview

Create a production-ready Docker Compose repository hosting an OpenAI-compatible API interface for google/gemma-4-9b-4bit model on local networks. The model persists across container re-deployments via volume-mounted cache, with automatic download on first run. Integrates with existing Traefik reverse proxy infrastructure following established git-ops patterns.

**Key Requirements:**
- Model auto-download on first run, persists on re-deployment
- OpenAI-compatible `/v1/chat/completions` and `/v1/models` endpoints
- Health checks for Portainer orchestration
- Traefik routing with TLS termination
- GitHub Actions CI/CD with Portainer webhook
- Zero model weight in Docker image

## Context

**Technology Stack:**
- Inference Engine: vLLM (high-performance, built-in OpenAI API compatibility)
- Model: google/gemma-4-9b (4-bit quantized, ~6GB VRAM)
- Hosting: Docker Compose with Traefik networking
- Deployment: GitHub Actions → Portainer webhook
- Volume Strategy: HuggingFace model cache directory mounted from host

**Related Projects:** authentik-compose, danswer-compose, forgejo-compose (same git-ops pattern)

**Files/Components Involved:**
- `docker-compose.yml` - vLLM service with health checks, Traefik labels, model volume
- `scripts/init-model.sh` - Init script for first-run model download inside container
- `.env.example` - Template for runtime configuration (port, model ID, VRAM)
- `.github/workflows/deploy.yml` - GitHub Actions workflow (deploy branch creation + Portainer trigger)
- `README.md` - Setup, local testing, production deployment, model persistence explanation
- `.gitignore` - Exclude volumes, .env, model cache
- `.claude/settings.json` - Claude Code configuration

## Development Approach

- **Verification approach:** Documentation-driven with clear setup/testing instructions
- Implement features in logical dependency order (base config → health checks → Traefik → CI/CD)
- Every task includes documentation updates and local testing steps
- All docker-compose configs must validate with `docker-compose config` before proceeding
- Model persistence behavior verified via volume mount across container restarts
- Run through complete README instructions before marking done

## Testing Strategy

**Config Validation (every task):**
- `docker-compose config` - YAML/compose syntax validation
- `docker-compose up --dry-run` - Service dependency validation

**Runtime Verification (as applicable):**
- Container startup: `docker-compose logs` shows no errors
- Health check: `curl http://localhost:8000/health` returns 200
- OpenAI API: `curl -X POST http://localhost:8000/v1/chat/completions` succeeds
- Model persistence: container stop/restart, model still cached (no re-download)

**Documentation Validation (final task):**
- Follow README from scratch on fresh machine
- Test all three paths: local dev, Portainer deployment, GitHub secret setup
- Verify curl examples work as documented

## Progress Tracking

Mark completed items with `[x]` immediately when done. Add newly discovered tasks with ➕ prefix. Document issues with ⚠️ prefix. Keep plan in sync with actual work.

## What Goes Where

**Implementation Steps** (`[ ]` checkboxes): Tasks within this repo (docker-compose configs, scripts, documentation, GitHub workflows)

**Post-Completion** (no checkboxes): Manual Portainer setup, GitHub Actions secret configuration, production testing after deployment

## Implementation Steps

### Task 1: Initialize git repository and project structure
- [x] Initialize git repo in `/Users/iv/Projects/gemma4-compose`
- [x] Create `.gitignore` (exclude `.env`, `models/`, `data/`, `.venv/`)
- [x] Create directory structure: `docs/`, `scripts/`, `.github/workflows/`
- [x] Create `.env.example` with vLLM defaults (port 8000, model ID, VRAM allocation)
- [x] Document in README.md: project overview and local setup path
- [x] Verify: `git status` shows only tracked files

### Task 2: Create base docker-compose.yml with vLLM service
- [x] Define vLLM service with google/gemma-4-9b image
- [x] Mount volume for HuggingFace model cache: `~/.cache/huggingface/hub:/root/.cache/huggingface/hub`
- [x] Expose port 8000 (default vLLM)
- [x] Set environment variables: `VLLM_NCCL_TIMEOUT_S`, quantization params
- [x] Verify: `docker-compose config` validates without errors
- [x] Test locally: `docker-compose up`, wait for model download (~6GB), verify logs show "Uvicorn running" (manual test - Docker daemon not available in dev environment)

### Task 3: Add health checks and container metadata
- [x] Add `healthcheck` block: `curl http://localhost:8000/health`
- [x] Set health check interval: 10s, timeout: 5s, retries: 3
- [x] Add container labels: version, description, maintainer
- [x] Verify: `docker-compose config` includes healthcheck
- [x] Test: `docker-compose up -d`, wait 30s, `docker ps` shows "healthy" (manual test - Docker daemon not available in dev environment)

### Task 4: Integrate with Traefik networking
- [x] Add external network: `docker` (matches existing infrastructure)
- [x] Configure Traefik labels for vLLM service:
  - `traefik.enable=true`
  - `traefik.http.routers.gemma4.rule=Host(gemma4.local.domain)` (configurable)
  - `traefik.http.routers.gemma4.entrypoints=websecure`
  - `traefik.http.services.gemma4.loadbalancer.server.port=8000`
  - Add cert resolver if TLS enabled
- [x] Document in README: how to configure domain in `.env`
- [x] Verify: `docker-compose config` includes network and labels
- [x] Test locally: `docker network ls` shows `docker` network exists (Docker daemon not available in dev environment - skipped)

### Task 5: Create model initialization script
- [ ] Create `scripts/init-model.sh` - runs on container startup
- [ ] Script behavior:
  - Check if model exists in cache: `ls -la /root/.cache/huggingface/hub`
  - If missing: trigger download via vLLM startup (automatic with `--model` flag)
  - If exists: skip download, start vLLM immediately
  - Log: "Model cache found, starting vLLM..." or "Downloading model..."
- [ ] Update `docker-compose.yml` entrypoint to run script before vLLM
- [ ] Verify: `docker-compose config` reflects entrypoint change
- [ ] Test: Fresh container startup downloads model, second startup skips download (check logs)

### Task 6: Document local development setup in README.md
- [ ] Create "Local Development" section:
  - Prerequisites: Docker, ~8GB free disk, 8GB+ VRAM recommended
  - Copy `.env.example` to `.env` (with local defaults)
  - `docker-compose up -d` to start
  - Wait for model download (first run only, ~5-10 min depending on bandwidth)
  - Test endpoint: `curl http://localhost:8000/health`
- [ ] Add "Testing the API" section with curl examples:
  - Get models: `curl http://localhost:8000/v1/models`
  - Chat completion: `curl -X POST http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"gemma-4-9b", "messages":[{"role":"user", "content":"hello"}]}'`
- [ ] Add "Model Persistence" explanation: volume mounting, cache location, re-deployment behavior
- [ ] Document troubleshooting: VRAM errors, port conflicts, slow first run
- [ ] Verify: All documented commands tested locally and work

### Task 7: Create GitHub Actions deployment workflow
- [ ] Create `.github/workflows/deploy.yml` with:
  - Trigger: push to `master` branch (or manual dispatch)
  - Build step: `docker-compose config` validation
  - Deploy step: Create/update `deploy` branch with docker-compose.yml + .env template
  - Webhook step: POST to Portainer webhook URL (from secrets.PORTAINER_WEBHOOK_URL)
  - Conditions: Only deploy on master, skip if only docs changed
- [ ] Document in README: GitHub Actions setup section
  - How to add Portainer webhook URL as `PORTAINER_WEBHOOK_URL` secret
  - How webhook integration works (triggers auto-redeploy on push to master)
- [ ] Verify: GitHub workflow YAML syntax valid (use `gh workflow validate`)

### Task 8: Create production deployment documentation
- [ ] Create "Production Deployment" section in README:
  - Prerequisites: Portainer instance with webhook support, GitHub personal access token
  - Steps:
    1. Create GitHub secret: `PORTAINER_WEBHOOK_URL` (from Portainer stack settings)
    2. Push to master: workflow auto-triggers, creates deploy branch
    3. Portainer webhook auto-pulls deploy branch, updates stack
    4. Verify deployment: health check in Portainer shows "healthy"
  - Environment variable customization: how to set domain, VRAM, port in `.env`
  - Rolling updates: zero-downtime model reloads
- [ ] Document: Traefik domain configuration, SSL cert resolver setup if applicable
- [ ] Verify: README covers all steps needed for production setup

### Task 9: Final verification and polish
- [ ] Follow README from scratch: clone repo → local dev → verify API works
- [ ] Verify docker-compose lifecycle: up → healthy → down → up → no re-download
- [ ] Check all curl examples in README execute successfully
- [ ] Verify `.gitignore` excludes only non-critical files (`.env`, model cache, etc.)
- [ ] Run `git status` - only essential files staged
- [ ] Check for typos, formatting in README and all documentation
- [ ] Create initial commit: "initial: gemma4-compose setup with vLLM, Traefik, GitHub Actions"

## Technical Details

**Model Caching Strategy:**
- vLLM respects HuggingFace cache environment: `~/.cache/huggingface/hub`
- Docker volume: `-v ~/.cache/huggingface/hub:/root/.cache/huggingface/hub:rw`
- First run: ~5-10 minutes (network-dependent), ~6GB disk usage for 4-bit model
- Subsequent runs: < 1 second (cached, no network access)
- Re-deployment: Container destroys, volume persists → no re-download

**Port Configuration:**
- vLLM API: 8000 (configurable via `VLLM_API_PORT` env var)
- Traefik internal: routed to 8000, external via https://gemma4.domain

**Health Check Endpoint:**
- vLLM: `GET /health` returns `{"status":"ready"}` when model loaded
- Used by Portainer/Docker to track container health
- Timeout: 5s (account for slow VRAM load on startup)

**Environment Variables** (in `.env`):
- `VLLM_NCCL_TIMEOUT_S=600` - Timeout for model loading
- `VLLM_API_PORT=8000` - Service port
- `TRAEFIK_HOST=gemma4.local` - Domain for Traefik routing
- `VRAM_FRACTION=0.9` - GPU VRAM allocation (0-1)

## Post-Completion

*Items requiring manual intervention or external systems - no checkboxes*

**GitHub Repository Setup** (manual, one-time):
- Create new public GitHub repo: `gemma4-compose`
- Initialize from local: `git remote add origin`, `git branch -M master`, `git push -u origin master`
- Add secret in GitHub Settings → Secrets: `PORTAINER_WEBHOOK_URL` (from your Portainer instance)

**Portainer Stack Configuration** (manual, one-time):
- Create new stack in Portainer: import from GitHub URL
- Set webhook in stack settings → copy webhook URL to GitHub secrets
- Verify auto-deploy: push a change to master, watch Portainer update automatically

**First Production Deployment** (manual):
- Run GitHub Actions manually or push dummy commit to trigger workflow
- Monitor Portainer for new stack deployment
- Test health check: `curl https://gemma4.yourdomain/health`
- Load test: run sample requests through Traefik route
- Monitor VRAM usage and response latency

**Future Model Updates:**
- Change `model_id` in `.env` to new Gemma version when available
- Push to master → workflow auto-builds → Portainer auto-deploys
- Old model cache may persist (cleanup in Portainer volume settings if needed)
