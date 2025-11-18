# Status Event Bridge for Open WebUI

**Real-time status updates from external SSE streaming APIs**

## Overview

The Status Event Bridge enables external streaming APIs (like robaiproxy/robaimultiturn) to send real-time status updates that appear in Open WebUI's interface **above the message content**, updating in real-time and automatically clearing when the response completes.

This solves the problem that Open WebUI's `__event_emitter__` only works for internal tools/functions, not external SSE streams.

### How It Works

```
External API (robaiproxy)
  → Sends SSE status events: data: {"type":"status","data":{...}}
  → Open WebUI middleware intercepts these events
  → Routes to Socket.IO event emitter
  → Frontend receives via WebSocket
  → Displays above message content
  → Replaces previous status (not appending)
  → Auto-clears when done=true
```

## Status Event Format

### SSE Format (What to Send)

```
data: {"type":"status","data":{"description":"Processing...","done":false,"hidden":false}}

```

**JSON Structure:**
```json
{
  "type": "status",
  "data": {
    "description": "⏱️  Turn 2 - Pondering... (10s)",
    "done": false,
    "hidden": false
  }
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `"status"` |
| `data` | object | Yes | Status data payload |
| `data.description` | string | Yes | Status message to display |
| `data.done` | boolean | Yes | `false` = in progress, `true` = completed (clears status) |
| `data.hidden` | boolean | Yes | `false` = visible, `true` = auto-hide when done |

## Sending Status Events (Backend Code)

### Python Helper Function

Located in `robaimultiturn/common/streaming.py`:

```python
def create_status_event(
    description: str,
    done: bool = False,
    hidden: bool = False
) -> str:
    """
    Create Open WebUI status event for displaying progress updates.

    Args:
        description: Status message to display (e.g., "Processing data...")
        done: True when status is complete, False while in progress
        hidden: True to auto-hide when done, False to keep visible

    Returns:
        str: Formatted SSE status event string
    """
    event = {
        "type": "status",
        "data": {
            "description": description,
            "done": done,
            "hidden": hidden
        }
    }
    return f"data: {json.dumps(event)}\n\n"
```

### Usage Example

```python
from robaimultiturn.common.streaming import create_status_event

async def my_streaming_function():
    # Send status update
    yield create_status_event("⏱️  Turn 1 - Processing... (5s)", done=False)

    # Do work...
    await asyncio.sleep(5)

    # Send another update (replaces previous)
    yield create_status_event("⏱️  Turn 1 - Analyzing... (10s)", done=False)

    # Do more work...
    await asyncio.sleep(5)

    # Clear status when done
    yield create_status_event("", done=True, hidden=True)

    # Stream actual response
    yield create_sse_chunk("Based on my analysis...")
```

### Real-World Example (tool_loop.py)

```python
async for item_type, item_data in merged_stream:
    if item_type == "status":
        # Status update - send as Open WebUI status event
        yield create_status_event(item_data, done=False, hidden=False)

    elif item_type == "stream":
        text_chunk, extracted_tools, finish_data = item_data

        if text_chunk is not None:
            # Clear status before streaming response
            if not first_chunk_received:
                yield create_status_event("", done=True, hidden=True)
                first_chunk_received = True

            # Stream actual response
            yield create_sse_chunk(text_chunk, model=model_name)
```

## Patch Implementation

### Location

**File:** `/app/backend/open_webui/utils/middleware.py`
**Function:** `stream_body_handler()` around line 2438
**Injection Point:** After `data = json.loads(data)`

### Patch Code

```python
# Status Event Bridge: Route status events to Socket.IO
if isinstance(data, dict) and data.get("type") == "status":
    await event_emitter({
        "type": "status",
        "data": data.get("data", {})
    })
    continue  # Skip sending to frontend as content
```

### What It Does

1. **Detects** status events in SSE stream by checking `data["type"] == "status"`
2. **Extracts** the status payload from `data["data"]`
3. **Emits** via Socket.IO using existing `event_emitter` function
4. **Skips** sending to frontend as content (uses `continue`)

### Socket.IO Integration

The `event_emitter` function (in `socket/main.py`) automatically:
- Sends to all user's active sessions via WebSocket
- Saves to database if `type == "status"`
- Triggers frontend status display

## Dockerfile Integration

### Current Implementation

**File:** `/home/robiloo/Documents/robaitools/robaiwebui/Dockerfile`

```dockerfile
# Patch 3: Status Event Bridge - Route SSE status events to Socket.IO
# File: /app/backend/open_webui/utils/middleware.py (after line ~2438)
# Intercepts status events from external SSE streams and emits via Socket.IO
RUN sed -i '/data = json.loads(data)/a\\n                            # Status Event Bridge: Route status events to Socket.IO\n                            if isinstance(data, dict) and data.get("type") == "status":\n                                await event_emitter({\n                                    "type": "status",\n                                    "data": data.get("data", {})\n                                })\n                                continue  # Skip sending to frontend as content' \
    /app/backend/open_webui/utils/middleware.py

# Verify patches were applied successfully
RUN echo "=== Verifying Patches ===" && \
    grep -n 'Status Event Bridge' /app/backend/open_webui/utils/middleware.py && \
    echo "=== Patches Applied Successfully ==="
```

### Rebuilding Container

```bash
# Build new image with patch
docker compose build open-webui

# Restart with patched image
docker compose up -d open-webui

# Verify patch is active
docker exec open-webui grep -A 6 "Status Event Bridge" /app/backend/open_webui/utils/middleware.py
```

## Standalone Patch Script

**File:** `/home/robiloo/Documents/robaitools/robaiwebui/patch-status-events.sh`

```bash
#!/bin/bash
# Patch Open WebUI to route status events from SSE to Socket.IO
# This enables real-time status updates from external streaming APIs

set -e

MIDDLEWARE_FILE="/app/backend/open_webui/utils/middleware.py"
PATCH_MARKER="# Status Event Bridge: Route status events to Socket.IO"

echo "🔧 Checking if status event bridge patch is needed..."

# Check if patch is already applied
if grep -q "$PATCH_MARKER" "$MIDDLEWARE_FILE" 2>/dev/null; then
    echo "✅ Status event bridge already applied, skipping patch"
    exit 0
fi

echo "📝 Applying status event bridge patch..."

# Create backup
cp "$MIDDLEWARE_FILE" "${MIDDLEWARE_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

# Find the line with "data = json.loads(data)" and inject after it
sed -i '/data = json.loads(data)/a\
\
                            # Status Event Bridge: Route status events to Socket.IO\
                            if isinstance(data, dict) and data.get("type") == "status":\
                                await event_emitter({\
                                    "type": "status",\
                                    "data": data.get("data", {})\
                                })\
                                continue  # Skip sending to frontend as content
' "$MIDDLEWARE_FILE"

echo "✅ Status event bridge patch applied successfully!"
```

**Usage:**
```bash
# Make executable
chmod +x patch-status-events.sh

# Apply to running container
docker exec open-webui /path/to/patch-status-events.sh

# Or run inside container
docker cp patch-status-events.sh open-webui:/tmp/
docker exec open-webui bash /tmp/patch-status-events.sh
```

## Frontend Display Behavior

### How Status Updates Appear

1. **Location:** Above the message content (not inside the response)
2. **Behavior:** Each new status **replaces** the previous one (not appending)
3. **Clearing:** Status automatically clears when `done: true` is sent
4. **Persistence:** Saved to database (can be retrieved later)

### Visual Example

```
┌─────────────────────────────────────┐
│ ⏱️  Turn 2 - Pondering... (10s)     │  ← Status (replaces previous)
├─────────────────────────────────────┤
│ Based on my analysis of the         │  ← Message content
│ documentation...                    │
└─────────────────────────────────────┘
```

After 10 seconds:
```
┌─────────────────────────────────────┐
│ ⏱️  Turn 2 - Thinking... (20s)      │  ← Status (replaced)
├─────────────────────────────────────┤
│ Based on my analysis of the         │  ← Message content (unchanged)
│ documentation...                    │
└─────────────────────────────────────┘
```

When LLM responds:
```
┌─────────────────────────────────────┐
│ Based on my analysis of the         │  ← Status cleared, response streams
│ documentation, async Python uses... │
└─────────────────────────────────────┘
```

## Testing

### Manual Test

1. **Start a chat** in Open WebUI at http://localhost
2. **Send a message** that triggers autonomous tool use (e.g., "research async python")
3. **Watch for status updates** appearing above the message
4. **Verify replacement** - each 10s update should replace the previous one
5. **Check clearing** - status should disappear when LLM starts responding

### Debug with Browser DevTools

1. Open **DevTools → Network tab**
2. Filter for **"socket.io"**
3. Look for **WebSocket frames** with `{"type":"status",...}`
4. Verify events are being received

### Check Logs

```bash
# View Open WebUI logs
docker logs open-webui -f

# View robaiproxy logs (sending status events)
cd robaiproxy && tail -f proxy.log

# Check for status event emission
docker exec open-webui grep "status" /app/backend/data/webui.log
```

### Verify Patch is Active

```bash
# Check middleware.py contains patch
docker exec open-webui grep -n "Status Event Bridge" /app/backend/open_webui/utils/middleware.py

# Should output:
# 2440:                            # Status Event Bridge: Route status events to Socket.IO
```

## Periodic Status Updates Pattern

### Common Pattern: Timer + Status Queue

```python
import asyncio
import time
from typing import AsyncGenerator

async def send_periodic_status_updates(
    turn: int,
    start_time: float,
    update_queue: asyncio.Queue,
    interval: float = 10.0
):
    """Send status updates every 10 seconds with cumulative elapsed time."""
    message_index = 0
    messages = ["Pondering...", "Thinking...", "Contemplating...", "Reflecting..."]

    try:
        while True:
            await asyncio.sleep(interval)

            elapsed = time.time() - start_time
            message = messages[message_index % len(messages)]

            status_text = f"⏱️  Turn {turn} - {message} ({elapsed:.0f}s)"
            await update_queue.put(status_text)

            message_index += 1
    except asyncio.CancelledError:
        pass

async def merge_stream_with_status(
    stream_generator,
    status_queue: asyncio.Queue
) -> AsyncGenerator[tuple, None]:
    """Merge LLM stream with periodic status updates."""
    stream_task = None
    stream_iter = stream_generator.__aiter__()
    status_get_task = None

    try:
        while True:
            # Create tasks if needed
            if stream_task is None or stream_task.done():
                stream_task = asyncio.create_task(stream_iter.__anext__())
            if status_get_task is None or status_get_task.done():
                status_get_task = asyncio.create_task(status_queue.get())

            # Race between stream and status
            done, _ = await asyncio.wait(
                [stream_task, status_get_task],
                return_when=asyncio.FIRST_COMPLETED
            )

            # Process completed (don't cancel pending!)
            for task in done:
                if task == stream_task:
                    try:
                        item = task.result()
                        yield ("stream", item)
                        stream_task = None
                    except StopAsyncIteration:
                        if status_get_task and not status_get_task.done():
                            status_get_task.cancel()
                        return
                elif task == status_get_task:
                    status_text = task.result()
                    yield ("status", status_text)
                    status_get_task = None
    finally:
        if stream_task and not stream_task.done():
            stream_task.cancel()

# Usage
async def my_handler():
    status_queue = asyncio.Queue()
    start_time = time.time()

    # Start periodic updater
    status_task = asyncio.create_task(
        send_periodic_status_updates(1, start_time, status_queue)
    )

    # Merge stream with status
    async for item_type, item_data in merge_stream_with_status(llm_stream, status_queue):
        if item_type == "status":
            yield create_status_event(item_data, done=False)
        elif item_type == "stream":
            # Cancel status on first chunk
            status_task.cancel()
            yield create_status_event("", done=True, hidden=True)
            yield create_sse_chunk(item_data)
```

## Troubleshooting

### Status Updates Not Appearing

**Check 1:** Verify patch is applied
```bash
docker exec open-webui grep -c "Status Event Bridge" /app/backend/open_webui/utils/middleware.py
# Should output: 1
```

**Check 2:** Verify SSE format is correct
```bash
# Test endpoint directly
curl -N http://localhost:8079/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3-30B","messages":[{"role":"user","content":"research async"}],"stream":true}' \
  | grep '"type":"status"'
```

**Check 3:** Check WebSocket connection
- Open browser DevTools → Network
- Filter for "socket.io"
- Verify WebSocket connection is active
- Check for frames containing `{"type":"status"}`

### Status Appears as Text Content

**Problem:** Status events are being displayed as message content instead of status indicators.

**Solution:** The patch might not be active. The `continue` statement prevents status events from being sent to content stream. Rebuild container:
```bash
docker compose build open-webui
docker compose up -d open-webui
```

### Status Updates Accumulate Instead of Replacing

**Problem:** Each status appears on a new line instead of replacing.

**Cause:** Frontend is receiving status events but not as WebSocket events.

**Solution:** Verify `event_emitter` is being called. Check Open WebUI logs:
```bash
docker logs open-webui 2>&1 | grep -i "status"
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Backend (robaiproxy/robaimultiturn)                             │
│                                                                  │
│  async def handler():                                           │
│    yield create_status_event("Processing...", done=False)  ─┐   │
│    # ... do work ...                                        │   │
│    yield create_status_event("", done=True)                │   │
│    yield create_sse_chunk("Based on...")                   │   │
└─────────────────────────────────────────────────────────────│───┘
                                                              │
                                    SSE Stream                │
                data: {"type":"status","data":{...}}          │
                                                              │
                                                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Open WebUI Middleware (middleware.py:2440)                      │
│                                                                  │
│  if data.get("type") == "status":                               │
│    await event_emitter({                                        │
│      "type": "status",                                          │
│      "data": data.get("data", {})                               │
│    })                                                           │
│    continue  # Don't send as content                            │
└─────────────────────────────────────────────────────────────────┘
                                     │
                                     │ Socket.IO
                            event: "events"
                                     │
                                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Frontend (Browser)                                               │
│                                                                  │
│  ┌──────────────────────────────────┐                           │
│  │ ⏱️  Turn 2 - Processing... (10s) │ ← Status Display          │
│  ├──────────────────────────────────┤                           │
│  │ Based on my analysis...          │ ← Message Content         │
│  └──────────────────────────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
```

## Related Files

| File | Purpose |
|------|---------|
| `robaimultiturn/common/streaming.py` | Helper function `create_status_event()` |
| `robaimultiturn/autonomous/tool_loop.py` | Usage example with periodic updates |
| `robaiwebui/Dockerfile` | Patch integration (build-time) |
| `robaiwebui/patch-status-events.sh` | Standalone patch script (runtime) |
| `open-webui/backend/utils/middleware.py` | Patch location (line 2440) |
| `open-webui/backend/socket/main.py` | Event emitter implementation |

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2024-11-17 | 1.0.0 | Initial implementation of Status Event Bridge |

## Credits

Implemented as part of the robaitools RAG system to enable real-time status updates during autonomous tool execution and multi-turn research workflows.
