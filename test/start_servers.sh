#!/bin/bash
set -e

echo "=== Starting Test Infrastructure ==="

# Start Mock LLM
echo "Starting Mock LLM Server..."
bun run test/mock_llm_server.ts &
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
  exit 1
fi

# Copy config to opencode directory
echo "Setting up opencode config..."
mkdir -p opencode/packages/opencode/.opencode
cp test/opencode.test.yaml opencode/packages/opencode/.opencode/opencode.yaml

# Start OpenCode
echo "Starting OpenCode Server..."
cd opencode/packages/opencode
bun run src/cli/cmd/serve.ts &
SERVER_PID=$!
cd ../..

# Wait for opencode server with better health check
echo "Waiting for OpenCode server..."
for i in {1..60}; do
  if curl -s http://localhost:4096/global/health > /dev/null 2>&1; then
    echo "✓ OpenCode server ready on port 4096"
    break
  fi
  sleep 1
done

if ! curl -s http://localhost:4096/global/health > /dev/null 2>&1; then
  echo "✗ OpenCode server failed to start"
  kill $MOCK_PID 2>/dev/null || true
  exit 1
fi

# Test that session creation works
echo "Testing session creation..."
if curl -s -X POST http://localhost:4096/session \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Session"}' > /dev/null 2>&1; then
  echo "✓ Session creation works"
else
  echo "⚠ Session creation test failed (server may need more time to initialize)"
fi

echo "=== Infrastructure Ready ==="
echo "Mock PID: $MOCK_PID"
echo "Server PID: $SERVER_PID"

# Export PIDs for cleanup
export MOCK_PID=$MOCK_PID
export SERVER_PID=$SERVER_PID