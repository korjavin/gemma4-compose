# gemma4-compose

Docker Compose stack that runs [Ollama](https://ollama.com) behind a Bearer-token Caddy auth-proxy, published via Traefik with TLS. Gives you an OpenAI-compatible API over HTTPS for Gemma 4, Qwen, Llama, or any other Ollama-supported model, with persistent on-disk model cache and GitHub Actions → Portainer deployment.

## Architecture

```
       HTTPS
  Client ──► Traefik ──► auth-proxy (Caddy) ──► Ollama
  Bearer    (TLS)        checks Authorization    port 11434
                         header: Bearer $API_KEY (internal only)
```

- **ollama** — runs the model. Exposed only on the internal Docker network; never reachable directly from outside.
- **auth-proxy** — Caddy container that validates `Authorization: Bearer $API_KEY` and forwards everything to Ollama. Transparent proxy: all Ollama endpoints (chat, completions, pull, delete, list, embeddings) are reachable once authed.
- **Traefik** — external; handles TLS and routing via Docker labels on the auth-proxy.

The two containers talk over a private `internal` bridge network. The auth-proxy also sits on the external Traefik network. Ollama has no direct path to the outside.

## Quick start (local)

```bash
git clone https://github.com/korjavin/gemma4-compose.git
cd gemma4-compose
cp .env.example .env

# Generate an API key
openssl rand -hex 32
# paste it into .env as API_KEY=...

docker-compose up -d
docker-compose logs -f        # watch the model pull on first run
```

On first boot the container runs `ollama pull $OLLAMA_MODEL`. That takes a few minutes and only happens once — the blobs live on the host at `$MODEL_CACHE_PATH` and survive container restarts and image rebuilds.

For a pure local-dev session without Traefik, replace the Traefik network with a published port in a compose override, or hit the auth-proxy directly over its container network.

## Configuration

All settings live in `.env`. The defaults in `.env.example` are production-leaning; override as needed.

| Variable | Default | Purpose |
|---|---|---|
| `API_KEY` | *(required)* | Bearer token clients must send. Generate with `openssl rand -hex 32`. |
| `OLLAMA_MODEL` | `gemma4:e2b` | Model to pull on first boot. Any Ollama library ref works (`gemma4:e2b`, `qwen3:14b`, `llama3:8b`, …). |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long the model stays resident in RAM after the last request. Set to `-1` to keep forever, `0` to unload immediately. |
| `MODEL_CACHE_PATH` | `/mnt/HC_Volume_105196246/ollama_cache` | Host path for `/root/.ollama` (models, manifests, blobs). Point this at a volume with enough free space. |
| `NETWORK_NAME` | `docker` | Name of the external Traefik network to join. |
| `TRAEFIK_HOST` | `gemma4.local` | Hostname Traefik routes to this stack. |
| `TRAEFIK_ENTRYPOINT` | `websecure` | Traefik entrypoint (typically `websecure` for HTTPS). |
| `TRAEFIK_CERTRESOLVER` | `myresolver` | Name of your Traefik ACME cert resolver. |
| `CONTAINER_NAME` | `gemma4-api` | Base name for both containers (auth-proxy gets `-auth` suffix). |

## Production deployment (Portainer)

1. Ensure the cache directory exists on the host with write permission:
   ```bash
   sudo mkdir -p /mnt/HC_Volume_105196246/ollama_cache
   sudo chown -R 1000:1000 /mnt/HC_Volume_105196246/ollama_cache
   ```
2. In Portainer → Stacks → Add stack → Git repository:
   - Repository: `https://github.com/korjavin/gemma4-compose`
   - Branch: `deploy` (produced by GitHub Actions; contains only deployment-ready files)
   - Environment variables: set everything from the table above, at minimum `API_KEY`, `OLLAMA_MODEL`, `TRAEFIK_HOST`.
3. Enable the Portainer webhook on the stack. GitHub Actions calls that webhook on every push to `master`, so pushes to the repo trigger redeploys with the latest `ghcr.io/korjavin/gemma4-compose:latest` image.

## Using the API

Every request must carry the Bearer header. Both the OpenAI-compatible `/v1/*` paths and Ollama's native `/api/*` paths are reachable.

Export your key once:

```bash
export GEMMA_HOST=https://gemma4.yourdomain.com
export API_KEY=sk-your-key
```

### List installed models

```bash
curl -s $GEMMA_HOST/v1/models \
  -H "Authorization: Bearer $API_KEY" | jq

# Native form
curl -s $GEMMA_HOST/api/tags \
  -H "Authorization: Bearer $API_KEY" | jq
```

The `id` field in `/v1/models` is the exact string to pass as `"model"` in a chat request.

### Chat completion (OpenAI-compatible)

```bash
curl -s $GEMMA_HOST/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:e2b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Explain MoE models in one sentence."}
    ]
  }' | jq
```

Works directly with the OpenAI Python and Node SDKs — point `base_url` at `$GEMMA_HOST/v1` and pass your `API_KEY`.

### Streaming

```bash
curl -N $GEMMA_HOST/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemma4:e2b","messages":[{"role":"user","content":"hi"}],"stream":true}'
```

### Embeddings

```bash
curl -s $GEMMA_HOST/v1/embeddings \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemma4:e2b","input":"hello world"}' | jq
```

## Model management

**Clients never auto-download models** — an inference request for an unknown model returns `404`. Pulls only happen when you hit `/api/pull` explicitly or when `init-model.sh` runs on first boot.

The following endpoints let anyone holding `API_KEY` manage the model catalogue. Treat the key as having full admin rights over this Ollama instance.

### Pull a new model

```bash
curl -s $GEMMA_HOST/api/pull \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"qwen3:14b"}'
```

Streams progress lines. Once complete, the model is available for `/v1/chat/completions`.

### Delete a model

```bash
curl -s -X DELETE $GEMMA_HOST/api/delete \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"qwen3:14b"}'
```

Removes the manifest and garbage-collects any blobs no other model references. Safe — never hand-delete blob files on disk; blobs are content-addressed and shared across models.

### Copy / rename a model (useful for shortening pull refs)

```bash
curl -s $GEMMA_HOST/api/copy \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"source":"hf.co/unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ1_M","destination":"qwen3.6"}'
```

After this, clients can pass `"model": "qwen3.6"` instead of the full HF ref.

### Full API reference

Everything at [ollama.com/docs/api](https://github.com/ollama/ollama/blob/main/docs/api.md) and the OpenAI-compat subset at [ollama.com/docs/openai](https://github.com/ollama/ollama/blob/main/docs/openai.md) is reachable through the proxy — just add the Bearer header.

## Picking a model

Ollama library tags work out of the box. HuggingFace GGUFs work via `hf.co/<org>/<repo>:<quant-tag>` but only for architectures supported by the llama.cpp engine bundled with Ollama (see Troubleshooting below).

Rough sizing for common models:

| Model | RAM footprint | Notes |
|---|---|---|
| `gemma4:e2b` | ~2 GB | Multimodal edge model (text/image/audio/video). Fast on CPU. |
| `gemma4:e4b` | ~4 GB | Bigger sibling of E2B. |
| `qwen3:8b` | ~5 GB | Dense Qwen 3, snappy on 8 CPU cores. |
| `qwen3:14b` | ~9 GB | Dense Qwen 3, better quality, slower on CPU. |
| `qwen3.6:35b-a3b` | ~22 GB | MoE (35B total / 3B active). Fast per-token despite size, but needs a big box. |
| `llama3:8b` | ~5 GB | Solid general-purpose dense model. |
| `mistral:7b` | ~4 GB | Older but fast. |

On a 15 GB RAM / 8 CPU host without GPU, `qwen3:14b` is the sweet spot for quality; `gemma4:e2b` or `qwen3:8b` if you want speed.

Full catalogue: [ollama.com/library](https://ollama.com/library).

## Cache management

The Ollama cache lives at `$MODEL_CACHE_PATH` on the host and is bind-mounted to `/root/.ollama` inside the container. Contents:

- `models/manifests/…` — small JSON files pointing at blobs
- `models/blobs/sha256-…` — the actual weight files (content-addressed)

**Free space:**
```bash
# Via the API
curl -s -X DELETE $GEMMA_HOST/api/delete \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"<model>"}'

# Or exec into the container
docker exec gemma4-api ollama list
docker exec gemma4-api ollama rm <model>
```

**Inspect usage:**
```bash
du -sh $MODEL_CACHE_PATH/models/
docker exec gemma4-api ollama list
```

**Nuclear reset** (container must be stopped):
```bash
docker-compose down
sudo rm -rf $MODEL_CACHE_PATH/models
docker-compose up -d    # init script repulls $OLLAMA_MODEL
```

## Troubleshooting

### `401 Unauthorized - missing or invalid API key`

The Bearer header is missing or doesn't match `API_KEY` set in the stack env. Check with:
```bash
curl -I $GEMMA_HOST/v1/models -H "Authorization: Bearer $API_KEY"
```

### `500` with `unknown model architecture: 'qwen35moe'` in logs

Ollama ships two inference engines:

- **Go engine** — runs models from Ollama's native library (e.g. `qwen3.6:35b-a3b`). Supports modern architectures including qwen35moe.
- **llama.cpp engine** — fallback for imported GGUFs (e.g. `hf.co/...`). May lag behind on new architectures.

If a HuggingFace GGUF fails with this error, the llama.cpp bundled with the current Ollama version doesn't yet implement that architecture. Options: switch to an Ollama-library tag of the same model, pick a model on a supported architecture, or wait for the next Ollama release.

### First pull fails with `pull model manifest: file does not exist`

`OLLAMA_MODEL` is set to something that isn't a valid Ollama ref. Ollama accepts:
- Library tags: `gemma4:e2b`, `qwen3:14b`, `llama3:8b`
- HuggingFace GGUFs: `hf.co/<org>/<repo>:<quant-tag>`

HuggingFace repo IDs in transformers format (`google/gemma-4-E2B`) are **not** valid — those are safetensors weights, not GGUF.

### `Out of memory` / model fails to load

The model plus KV cache exceeds available RAM. Either pick a smaller quant, pick a smaller model, or reduce context via the `num_ctx` parameter on requests.

### Health check failing right after deploy

First-run model pulls can take 5–10 minutes. The healthcheck has a 5-minute `start_period`; if the pull takes longer the container can be marked unhealthy temporarily. Watch progress:
```bash
docker-compose logs -f ollama
```
Once the `Model ready` line appears, the health check passes on the next interval.

## Files

- `docker-compose.yml` — two services (`ollama`, `auth-proxy`), private `internal` network, Traefik labels on the proxy.
- `Dockerfile` — extends `ollama/ollama:0.21.0` (pinned) with an embedded init script that pulls `$OLLAMA_MODEL` before starting the server.
- `Dockerfile.caddy` — Caddy 2 with an embedded Caddyfile that gates all requests on `Authorization: Bearer $API_KEY`.
- `scripts/init-model.sh` — same init script as in the Dockerfile heredoc, kept as a reference copy.
- `.github/workflows/deploy.yml` — builds both images, pushes to GHCR, calls the Portainer webhook.

## License

MIT
