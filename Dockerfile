# L1 - KV-Cache Proxy (mallard1983/openclaw-kvcache-proxy)
# Strips message_id UUIDs + [Day YYYY-MM-DD HH:MM UTC] timestamps from
# Responses-API requests so llama-server's prompt cache stays warm.

FROM python:3.11-slim AS builder
WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim AS runtime
LABEL org.opencontainers.image.title="openclaw-kvcache-proxy"
LABEL org.opencontainers.image.source="https://github.com/mallard1983/openclaw-kvcache-proxy"

RUN groupadd -r app && useradd -r -g app app
WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    KVCACHE_LISTEN_PORT=1234 \
    KVCACHE_BACKEND_URL=http://llama-server:12345 \
    KVCACHE_LOG_FILE=/app/logs/proxy.log \
    KVCACHE_STRIP_MESSAGE_IDS=true \
    KVCACHE_STRIP_TIMESTAMPS=true

COPY --chown=app:app proxy.py /app/proxy.py
COPY --chown=app:app llm_proxy_logger.py /app/llm_proxy_logger.py
COPY --chown=app:app proxy_env.py /app/proxy_env.py

RUN mkdir -p /app/logs && chown app:app /app /app/logs \
 && touch /app/proxy.log && chown app:app /app/proxy.log

USER app
EXPOSE 1234

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys,os; urllib.request.urlopen(f'http://127.0.0.1:{os.environ[\"KVCACHE_LISTEN_PORT\"]}/health', timeout=3).read()" || exit 1

CMD ["sh", "-c", "uvicorn proxy_env:app --host 0.0.0.0 --port ${KVCACHE_LISTEN_PORT}"]
