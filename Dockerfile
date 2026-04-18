FROM vllm/vllm-openai:0.4.0

WORKDIR /app

# Copy init script
COPY scripts/init-model.sh /scripts/init-model.sh
RUN chmod +x /scripts/init-model.sh

# Create non-root user for security
RUN useradd -m -u 1000 vllm && \
    chown -R vllm:vllm /app /root/.cache

USER vllm

# Health check endpoint
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=900s \
    CMD curl -f http://localhost:8000/health || exit 1

ENTRYPOINT ["/bin/bash"]
CMD ["/scripts/init-model.sh"]
