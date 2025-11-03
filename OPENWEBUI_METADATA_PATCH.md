# Open-WebUI Metadata Passthrough Patch

## Purpose
Enable Open-WebUI to send metadata (chat_id, session_id, user_id, etc.) to backend LLM servers for session tracking.

## Files to Modify

### 1. `/app/backend/open_webui/env.py`
**Line:** ~212
**Change:** Default ENABLE_FORWARD_USER_INFO_HEADERS to True

```python
# BEFORE:
ENABLE_FORWARD_USER_INFO_HEADERS = (
    os.environ.get("ENABLE_FORWARD_USER_INFO_HEADERS", "False").lower() == "true"
)

# AFTER:
ENABLE_FORWARD_USER_INFO_HEADERS = (
    os.environ.get("ENABLE_FORWARD_USER_INFO_HEADERS", "True").lower() == "true"
)
```

**Effect:** Always forwards user info headers unless explicitly disabled.

---

### 2. `/app/backend/open_webui/routers/openai.py`
**Line:** ~790 (in `generate_chat_completion` function)
**Change:** Use `.get()` instead of `.pop()` to preserve metadata in payload

```python
# BEFORE:
payload = {**form_data}
metadata = payload.pop("metadata", None)

# AFTER:
payload = {**form_data}
metadata = payload.get("metadata", None)
```

**Effect:** Metadata stays in request body sent to backend LLM server.

---

## Result

### Headers Sent to Backend:
- `X-OpenWebUI-User-Name`
- `X-OpenWebUI-User-Id`
- `X-OpenWebUI-User-Email`
- `X-OpenWebUI-User-Role`
- `X-OpenWebUI-Chat-Id` (if chat_id exists)

### Body Sent to Backend:
```json
{
  "messages": [...],
  "model": "...",
  "metadata": {
    "user_id": "...",
    "chat_id": "...",
    "session_id": "...",
    "message_id": "...",
    "filter_ids": [...],
    "tool_ids": [...],
    "files": [...],
    "features": {...},
    "variables": {...}
  }
}
```

---

## Testing Patch

1. Check if headers are being sent:
   ```bash
   # In backend server, log incoming headers
   logger.info(f"Headers: {request.headers}")
   ```

2. Check if metadata is in body:
   ```python
   body = await request.json()
   metadata = body.get("metadata", {})
   logger.info(f"Metadata: {metadata}")
   ```

---

## Quick Patch Script

```bash
# For new Open-WebUI versions
docker cp container:/app/backend/open_webui/env.py ./env.py
docker cp container:/app/backend/open_webui/routers/openai.py ./openai.py

# Edit files (apply changes above)

docker cp ./env.py container:/app/backend/open_webui/env.py
docker cp ./openai.py container:/app/backend/open_webui/routers/openai.py

# Restart container
docker restart container
```

---

## Version Info
- **Patched Version:** ghcr.io/open-webui/open-webui:main (as of 2025-11-01)
- **Base Commit:** 171021cfa4276f63fd9fd7f31fa0c904fb13c24c
