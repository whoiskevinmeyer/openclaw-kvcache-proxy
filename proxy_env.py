"""
Env-var wrapper around upstream proxy.py.

Upstream proxy.py exposes 5 hardcoded module-level constants:
  LISTEN_PORT, BACKEND_URL, LOG_FILE, STRIP_MESSAGE_IDS, STRIP_TIMESTAMPS

Production needs these overridable from the environment without forking
upstream. This wrapper imports proxy, mutates the constants from env,
then re-exports `app` so `uvicorn proxy_env:app` works.
"""

import os
import logging
import proxy

LISTEN_PORT = int(os.getenv("KVCACHE_LISTEN_PORT", str(proxy.LISTEN_PORT)))
BACKEND_URL = os.getenv("KVCACHE_BACKEND_URL", proxy.BACKEND_URL)
LOG_FILE = os.getenv("KVCACHE_LOG_FILE", proxy.LOG_FILE)
STRIP_MESSAGE_IDS = os.getenv("KVCACHE_STRIP_MESSAGE_IDS", "true").lower() in ("1", "true", "yes")
STRIP_TIMESTAMPS = os.getenv("KVCACHE_STRIP_TIMESTAMPS", "true").lower() in ("1", "true", "yes")

proxy.LISTEN_PORT = LISTEN_PORT
proxy.BACKEND_URL = BACKEND_URL
proxy.LOG_FILE = LOG_FILE
proxy.STRIP_MESSAGE_IDS = STRIP_MESSAGE_IDS
proxy.STRIP_TIMESTAMPS = STRIP_TIMESTAMPS

logging.getLogger(__name__).info(
    "kvcache-proxy env override: port=%d backend=%s strip_ids=%s strip_ts=%s",
    LISTEN_PORT, BACKEND_URL, STRIP_MESSAGE_IDS, STRIP_TIMESTAMPS,
)

app = proxy.app
