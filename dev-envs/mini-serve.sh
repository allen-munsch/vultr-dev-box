#!/usr/bin/env bash
for PORT in "${@:-8000}"; do
    echo "🚀 Serving on http://localhost:$PORT"
    python3 -m http.server "$PORT" &
done
echo "Press Ctrl+C to stop"
wait
