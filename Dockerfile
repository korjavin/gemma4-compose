FROM ollama/ollama:latest

WORKDIR /app

# Copy init script
COPY scripts/init-model.sh /scripts/init-model.sh
RUN chmod +x /scripts/init-model.sh

# Ollama will run as default CMD, we override with init script
ENTRYPOINT ["/bin/bash"]
CMD ["/scripts/init-model.sh"]
