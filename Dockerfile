# Open-WebUI with Metadata Passthrough Patch
# Applies patches from OPENWEBUI_METADATA_PATCH.md
FROM ghcr.io/open-webui/open-webui:main

# Patch 1: Enable ENABLE_FORWARD_USER_INFO_HEADERS by default
# File: /app/backend/open_webui/env.py (line ~212)
# Changes default from "False" to "True"
RUN sed -i 's/os\.environ\.get("ENABLE_FORWARD_USER_INFO_HEADERS", "False")/os.environ.get("ENABLE_FORWARD_USER_INFO_HEADERS", "True")/' \
    /app/backend/open_webui/env.py

# Patch 2: Preserve metadata in payload (use .get() instead of .pop())
# File: /app/backend/open_webui/routers/openai.py (line ~790)
# Keeps metadata in request body sent to backend LLM server
RUN sed -i 's/metadata = payload\.pop("metadata", None)/metadata = payload.get("metadata", None)/' \
    /app/backend/open_webui/routers/openai.py

# Patch 3: Status Event Bridge - Route SSE status events to Socket.IO
# File: /app/backend/open_webui/utils/middleware.py (after line ~2438)
# Intercepts status events from external SSE streams and emits via Socket.IO
RUN sed -i '/data = json.loads(data)/a\\n                            # Status Event Bridge: Route status events to Socket.IO\n                            if isinstance(data, dict) and data.get("type") == "status":\n                                await event_emitter({\n                                    "type": "status",\n                                    "data": data.get("data", {})\n                                })\n                                continue  # Skip sending to frontend as content' \
    /app/backend/open_webui/utils/middleware.py

# Verify patches were applied successfully
RUN echo "=== Verifying Patches ===" && \
    grep -n 'ENABLE_FORWARD_USER_INFO_HEADERS.*"True"' /app/backend/open_webui/env.py && \
    grep -n 'metadata = payload\.get("metadata"' /app/backend/open_webui/routers/openai.py && \
    grep -n 'Status Event Bridge' /app/backend/open_webui/utils/middleware.py && \
    echo "=== Patches Applied Successfully ==="

# Keep the original entrypoint and command from base image
