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
# The patch detects status events and routes them to Socket.IO instead of content stream
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
echo "📍 Modified: $MIDDLEWARE_FILE"
echo "💾 Backup saved: ${MIDDLEWARE_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
