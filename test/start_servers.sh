#!/bin/bash
set -e

echo "=== Starting Test Infrastructure ==="

# Start Mock LLM
echo "Starting Mock LLM Server..."
bun run test/mock_llm_server.ts > /tmp/mock_server.log 2>&1 &
MOCK_PID=$!

# Wait for mock server
for i in {1..30}; do
  if curl -s http://localhost:4097/health > /dev/null 2>&1; then
    echo "✓ Mock server ready on port 4097"
    break
  fi
  sleep 1
done

if ! curl -s http://localhost:4097/health > /dev/null 2>&1; then
  echo "✗ Mock server failed to start"
  echo "Mock server logs:"
  cat /tmp/mock_server.log || true
  exit 1
fi

# Setup config in opencode directory
echo "Setting up opencode config..."
mkdir -p opencode/packages/opencode/.opencode
cp test/opencode.test.yaml opencode/packages/opencode/.opencode/opencode.yaml

# Change to opencode directory and start server
echo "Starting OpenCode Server..."
cd opencode/packages/opencode

# Start server with logging
bun run src/cli/cmd/serve.ts > /tmp/opencode_server.log 2>&1 &
SERVER_PID=$!

# Go back to root
cd ../../..

# Wait for opencode server
echo "Waiting for OpenCode server (up to 60s)..."
for i in {1..60}; do
  if curl -s http://localhost:4096/global/health > /dev/null 2>&1; then
    echo "✓ OpenCode server ready on port 4096"
    break
  fi
  
  # Check if server process is still running
  if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo "✗ OpenCode server process died"
    echo "Server logs:"
    cat /tmp/opencode_server.log || true
    kill $MOCK_PID 2>/dev/null || true
    exit 1
  fi
  
  sleep 1
done

if ! curl -s http://localhost:4096/global/health > /dev/null 2>&1; then
  echo "✗ OpenCode server failed to start"
  echo "Server logs:"
  cat /tmp/opencode_server.log || true
  kill $MOCK_PID 2>/dev/null || true
  kill $SERVER_PID 2>/dev/null || true
  exit 1
fi

# Test session creation
echo "Testing session creation..."
SESSION_RESPONSE=$(curl -s -X POST http://localhost:4096/session \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Session"}' 2>&1)

if [ -n "$SESSION_RESPONSE" ]; then
  echo "✓ Session creation works (response: $SESSION_RESPONSE)"
else
  echo "⚠ Session creation returned empty response"
fi

echo "=== Infrastructure Ready ==="
echo "Mock PID: $MOCK_PID"
echo "Server PID: $SERVER_PID"

# Export PIDs for cleanup
export MOCK_PID=$MOCK_PID
export SERVER_PID=$SERVER_PID