#!/usr/bin/env bash

# Helper script to recreate BuildKit container with insecure registry config
#
# This script recreates the BuildKit container after `kamal build create`
# and mounts the /etc/buildkit/buildkitd.toml file from the remote host.
#
# Usage:
#   .kamal/scripts/recreate-buildkit-container.sh
#
# Prerequisite:
#   - /etc/buildkit/buildkitd.toml must exist on remote host
#   - Builder must be created with `kamal build create` first

set -e

# Read configuration from config/deploy.yml
REMOTE_SSH=$(ruby -ryaml -e "puts YAML.load_file('config/deploy.yml')['builder']['remote']")

# Extract user@host from SSH URL
REMOTE_HOST=$(echo "$REMOTE_SSH" | sed 's|ssh://||')

# Calculate default Kamal builder name
# Kamal uses: "kamal-remote-#{remote.gsub(/[^a-z0-9_-]/, "-")}"
BUILDER_NAME=$(ruby -e "puts 'kamal-remote-' + '$REMOTE_SSH'.gsub(/[^a-z0-9_-]/, '-')")

echo "======================================"
echo "Recreating BuildKit container"
echo "======================================"
echo ""
echo "Builder name: $BUILDER_NAME"
echo "Remote host: $REMOTE_HOST"
echo ""

# Recreate the BuildKit container with config file mounted
ssh "$REMOTE_HOST" << EOF
  set -e

  CONTAINER_NAME="buildx_buildkit_${BUILDER_NAME}0"
  VOLUME_NAME="buildx_buildkit_${BUILDER_NAME}0_state"

  echo "Stopping and removing \$CONTAINER_NAME..."
  docker stop \$CONTAINER_NAME 2>/dev/null || true
  docker rm \$CONTAINER_NAME 2>/dev/null || true

  echo "Creating new BuildKit container with config mounted..."
  docker run -d \
    --name \$CONTAINER_NAME \
    --restart unless-stopped \
    --net host \
    --privileged \
    -v /etc/buildkit/buildkitd.toml:/etc/buildkit/buildkitd.toml:ro \
    -v \$VOLUME_NAME:/var/lib/buildkit \
    moby/buildkit:buildx-stable-1 \
    --config /etc/buildkit/buildkitd.toml \
    --allow-insecure-entitlement=network.host

  echo ""
  echo "Verifying config file in container..."
  docker exec \$CONTAINER_NAME cat /etc/buildkit/buildkitd.toml
  echo ""
  echo "BuildKit container ready!"
EOF

echo ""
echo "======================================"
echo "BuildKit container recreated successfully!"
echo "======================================"
echo ""
echo "You can now run: bin/kamal build push"
