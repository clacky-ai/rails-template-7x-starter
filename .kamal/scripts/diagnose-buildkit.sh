#!/usr/bin/env bash
# Diagnose and fix BuildKit insecure registry configuration
#
# Run this script ON the remote server to diagnose and fix the BuildKit configuration
#
# Usage:
#   ssh ubuntu@106.52.39.164
#   bash diagnose-buildkit.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  BuildKit Insecure Registry Diagnostics${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Check BuildKit containers
echo -e "${BLUE}Step 1: Checking BuildKit containers...${NC}"
echo ""

BUILDKIT_CONTAINERS=$(docker ps -a --filter name=buildx_buildkit --format "{{.Names}}")

if [ -z "$BUILDKIT_CONTAINERS" ]; then
  echo -e "${RED}✗ No BuildKit containers found${NC}"
  echo "  Please run: kamal build create"
  exit 1
else
  echo -e "${GREEN}✓ Found BuildKit containers:${NC}"
  docker ps -a --filter name=buildx_buildkit --format "  {{.Names}}: {{.Status}}"
  echo ""
fi

# Step 2: Check BuildKit configuration file
echo -e "${BLUE}Step 2: Checking BuildKit configuration file...${NC}"
echo ""

if [ ! -f /etc/buildkit/buildkitd.toml ]; then
  echo -e "${RED}✗ Configuration file /etc/buildkit/buildkitd.toml not found${NC}"
  echo ""
  echo -e "${YELLOW}Creating configuration file...${NC}"

  sudo mkdir -p /etc/buildkit
  sudo tee /etc/buildkit/buildkitd.toml > /dev/null << 'EOF'
[registry."172.17.0.1:5000"]
  http = true
  insecure = true
EOF

  echo -e "${GREEN}✓ Configuration file created${NC}"
else
  echo -e "${GREEN}✓ Configuration file exists${NC}"
  echo ""
  echo "Content:"
  sudo cat /etc/buildkit/buildkitd.toml
fi

echo ""

# Step 3: Check if config is mounted in containers
echo -e "${BLUE}Step 3: Checking if config is mounted in containers...${NC}"
echo ""

for CONTAINER in $BUILDKIT_CONTAINERS; do
  echo "Checking container: $CONTAINER"

  # Check if container is running
  if ! docker inspect --format='{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo -e "${YELLOW}  ⚠ Container is not running${NC}"
    continue
  fi

  # Check if config file exists in container
  if docker exec "$CONTAINER" test -f /etc/buildkit/buildkitd.toml 2>/dev/null; then
    echo -e "${GREEN}  ✓ Config file is mounted${NC}"
    echo "  Content in container:"
    docker exec "$CONTAINER" cat /etc/buildkit/buildkitd.toml | sed 's/^/    /'
  else
    echo -e "${RED}  ✗ Config file is NOT mounted${NC}"
    echo -e "${YELLOW}  → Container needs to be recreated with mounted config${NC}"
  fi
  echo ""
done

# Step 4: Offer to fix
echo -e "${BLUE}Step 4: Fix BuildKit containers${NC}"
echo ""

read -p "Do you want to recreate BuildKit containers with correct configuration? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping fix. Exiting..."
  exit 0
fi

echo ""
echo -e "${YELLOW}Recreating BuildKit containers...${NC}"
echo ""

for CONTAINER in $BUILDKIT_CONTAINERS; do
  echo "Processing: $CONTAINER"

  # Extract volume name
  VOLUME_NAME="${CONTAINER}_state"

  # Stop and remove container
  echo "  Stopping container..."
  docker stop "$CONTAINER" 2>/dev/null || true

  echo "  Removing container..."
  docker rm "$CONTAINER" 2>/dev/null || true

  # Recreate container with config mounted
  echo "  Creating new container with mounted config..."
  docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    --net host \
    --privileged \
    -v /etc/buildkit/buildkitd.toml:/etc/buildkit/buildkitd.toml:ro \
    -v "$VOLUME_NAME":/var/lib/buildkit \
    moby/buildkit:buildx-stable-1 \
    --config /etc/buildkit/buildkitd.toml \
    --allow-insecure-entitlement=network.host

  echo -e "${GREEN}  ✓ Container recreated${NC}"

  # Verify config is accessible
  sleep 2
  if docker exec "$CONTAINER" cat /etc/buildkit/buildkitd.toml > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ Config verified in container${NC}"
  else
    echo -e "${RED}  ✗ Config verification failed${NC}"
  fi

  echo ""
done

# Step 5: Final verification
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Final Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "BuildKit containers status:"
docker ps --filter name=buildx_buildkit --format "  {{.Names}}: {{.Status}}"
echo ""

echo "Configuration in containers:"
for CONTAINER in $BUILDKIT_CONTAINERS; do
  if docker inspect --format='{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo ""
    echo "Container: $CONTAINER"
    docker exec "$CONTAINER" cat /etc/buildkit/buildkitd.toml 2>/dev/null | sed 's/^/  /' || echo -e "${RED}  Failed to read config${NC}"
  fi
done

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Diagnostics and fix completed!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "  1. Try building again: kamal build push"
echo "  2. If still failing, check the error message"
echo ""
