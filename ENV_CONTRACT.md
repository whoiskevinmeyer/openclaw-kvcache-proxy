# L1 kvcache-proxy — Env Contract

Upstream `proxy.py` exposes **zero** env vars — five module-level Python constants only:

| Upstream constant | Type | Default | Effect |
|---|---|---|---|
| `LISTEN_PORT` | `int` | `1234` | uvicorn bind port |
| `BACKEND_URL` | `str` | `http://localhost:12345` | llama-server upstream URL |
| `LOG_FILE` | `str` | `proxy.log` | path passed to `logging.FileHandler` at import time |
| `STRIP_MESSAGE_IDS` | `bool` | `True` | strip `"message_id"` lines from system + user content |
| `STRIP_TIMESTAMPS` | `bool` | `True` | strip `[Day YYYY-MM-DD HH:MM UTC]` prefix from user text |

All five need env-var promotion before this can run as a container. Forking upstream is the wrong move (small repo, active author). Instead this build ships a `proxy_env.py` wrapper that mutates the constants from env then re-exports `app`:

| Env var | Default in container | Maps to |
|---|---|---|
| `KVCACHE_LISTEN_PORT` | `1234` | `proxy.LISTEN_PORT` |
| `KVCACHE_BACKEND_URL` | `http://llama-server:12345` | `proxy.BACKEND_URL` |
| `KVCACHE_LOG_FILE` | `/app/logs/proxy.log` | `proxy.LOG_FILE` (note: see caveat) |
| `KVCACHE_STRIP_MESSAGE_IDS` | `true` | `proxy.STRIP_MESSAGE_IDS` |
| `KVCACHE_STRIP_TIMESTAMPS` | `true` | `proxy.STRIP_TIMESTAMPS` |

## LOG_FILE caveat

`proxy.py` registers a `FileHandler(LOG_FILE)` at module-import time (line 69), which opens the file *before* the wrapper can override the constant. The override still takes effect for any post-import log writes, but the FileHandler is bound to the upstream default `proxy.log`. The Dockerfile pre-creates `/app/proxy.log` writable so the import-time handler succeeds; the wrapper also opens the wrapper-side LOG_FILE for application logs. If LOG_FILE behaviour is load-bearing for log aggregation, the fix is to send to stdout only and drop file handlers — done downstream by the log driver.

## API surface (unchanged from upstream)

- `POST /v1/responses` — normalize + forward (streaming SSE supported via `aiter_bytes`)
- `GET /v1/models` — passthrough
- `GET /health` — `{status: "ok", backend, strip_timestamps, strip_message_ids}`
- catch-all on every other path — passthrough proxy

## Hardware note

Upstream README is benchmarked on Strix Halo (AMD 8060S, 128GB UMA) with Qwen3-Coder-Next 80B Q6_K on llama.cpp Vulkan. The ~22× speedup figure is for that exact setup. Different hardware / model / backend will see different numbers but the qualitative behaviour (sim_best ≈ 0.15 → ≈ 0.95+ after stripping volatile fields) should hold for any cache-prompt-enabled llama-server with an OpenClaw-shaped prompt.
