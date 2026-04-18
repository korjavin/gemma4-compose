# syntax=docker/dockerfile:1.4
FROM ollama/ollama:latest

WORKDIR /app

# Create init script directly in image using heredoc
COPY <<'EOF' /scripts/init-model.sh
#!/bin/bash
set -e

# Start Ollama service in background
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Waiting for Ollama to start..."
for i in {1..30}; do
  if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Ollama is ready"
    break
  fi
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Waiting... ($i/30)"
  sleep 1
done

# Pull the model
MODEL="${OLLAMA_MODEL:-gemma:7b}"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Pulling model: $MODEL"
ollama pull "$MODEL"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Model ready. Ollama API running on port 11434"

# Keep the process alive
wait $OLLAMA_PID
EOF

RUN chmod +x /scripts/init-model.sh

ENTRYPOINT ["/bin/bash"]
CMD ["/scripts/init-model.sh"]
