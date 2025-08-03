#!/bin/bash

# MES Redis Infrastructure - Deploy Script
# This script deploys Redis to Kubernetes using Kustomize

set -e

# Configuration
ENVIRONMENT="${ENVIRONMENT:-localdev}"
NAMESPACE="${NAMESPACE:-mes-${ENVIRONMENT}}"

echo "Deploying Redis to Kubernetes..."
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo ""

# Validate environment
if [ ! -d "manifests/overlays/$ENVIRONMENT" ]; then
    echo "Error: Unknown environment '$ENVIRONMENT'"
    echo "Available environments:"
    ls -1 manifests/overlays/
    exit 1
fi

# Check if Kustomize is available
if command -v kustomize &> /dev/null; then
    echo "Using standalone Kustomize..."
    KUSTOMIZE_CMD="kustomize build"
else
    echo "Using kubectl integrated Kustomize..."
    KUSTOMIZE_CMD="kubectl kustomize"
fi

# Apply the Kubernetes manifests
echo "Applying manifests for $ENVIRONMENT environment..."
$KUSTOMIZE_CMD "manifests/overlays/$ENVIRONMENT" | kubectl apply -f - --overwrite=true || {
    echo "Error: Failed to apply Kubernetes manifests"
    echo "Attempting to debug..."
    $KUSTOMIZE_CMD "manifests/overlays/$ENVIRONMENT" | kubectl apply -f - --dry-run=client --validate=true
    exit 1
}

# Show deployment status
echo ""
echo "Deployment status:"
kubectl get all -n $NAMESPACE -l app=redis

echo ""
echo "Redis deployed successfully!"