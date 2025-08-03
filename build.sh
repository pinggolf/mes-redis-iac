#!/bin/bash

# MES Redis Infrastructure - Build Script
# This script builds the custom Redis Docker image

set -e

# Configuration
REGISTRY_NAME="${REGISTRY_NAME:-mes-redis}"
IMAGE_NAME="${IMAGE_NAME:-localdev}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE_NAME="$REGISTRY_NAME:$IMAGE_NAME"

echo "Building Redis Docker image..."
echo "Image: $FULL_IMAGE_NAME"
echo ""

# Ensure redis configuration exists
if [ ! -f "redis-configs/redis.conf" ]; then
    echo "Error: redis-configs/redis.conf not found"
    echo "Creating default Redis configuration..."
    mkdir -p redis-configs
    cp manifests/overlays/localdev/redis.conf redis-configs/redis.conf
fi

# Build the Docker image
docker build -f Dockerfile . -t "$FULL_IMAGE_NAME" || {
    echo "Error: Failed to build Docker image"
    exit 1
}

# Tag the image for Kubernetes
docker tag "$FULL_IMAGE_NAME" "$FULL_IMAGE_NAME-$IMAGE_TAG"

echo ""
echo "Docker image built successfully: $FULL_IMAGE_NAME"
echo ""

# Optional: List the image
docker images | grep "$REGISTRY_NAME" | head -5