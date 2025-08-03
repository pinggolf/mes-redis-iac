#!/bin/bash

# MES Redis Infrastructure - Clean Script
# This script removes Redis deployment from Kubernetes

set -e

# Configuration
ENVIRONMENT="${ENVIRONMENT:-localdev}"
NAMESPACE="${NAMESPACE:-mes-${ENVIRONMENT}}"

echo "========================================="
echo "MES Redis Infrastructure Cleanup"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo ""

# Check if Kustomize is available
if command -v kustomize &> /dev/null; then
    KUSTOMIZE_CMD="kustomize build"
else
    KUSTOMIZE_CMD="kubectl kustomize"
fi

# Delete the Kubernetes resources
echo "Removing Redis deployment..."
$KUSTOMIZE_CMD "manifests/overlays/$ENVIRONMENT" | kubectl delete -f - --ignore-not-found=true || {
    echo "Warning: Some resources may not have been deleted"
}

# Delete secrets
echo "Removing secrets..."
kubectl delete secret redis-secret --namespace=$NAMESPACE --ignore-not-found=true || true
kubectl delete secret redis-credentials --namespace=default --ignore-not-found=true || true
kubectl delete secret redis-credentials --namespace=mes --ignore-not-found=true || true

# Delete PVCs (Persistent Volume Claims)
echo "Removing persistent volume claims..."
kubectl delete pvc -n $NAMESPACE -l app=redis --ignore-not-found=true || true

# Delete namespace if empty (only for non-default namespaces)
if [ "$NAMESPACE" != "default" ]; then
    # Check if namespace is empty
    RESOURCE_COUNT=$(kubectl get all -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ "$RESOURCE_COUNT" -eq "0" ]; then
        echo "Removing empty namespace..."
        kubectl delete namespace $NAMESPACE --ignore-not-found=true || true
    else
        echo "Namespace $NAMESPACE is not empty, keeping it."
    fi
fi

echo ""
echo "Redis cleanup completed!"
echo ""

# Show remaining resources
echo "Remaining resources in namespace $NAMESPACE:"
kubectl get all -n $NAMESPACE 2>/dev/null || echo "Namespace $NAMESPACE no longer exists."

# Optionally remove Redis entries from mes-system-env configmap
if kubectl get configmap mes-system-env &>/dev/null; then
    echo ""
    echo "Found mes-system-env configmap. The Redis entries can be removed."
    if [ "$1" != "--force" ]; then
        read -p "Remove REDIS_HOST and REDIS_PORT from mes-system-env configmap? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Removing Redis entries from mes-system-env configmap..."
            # Remove REDIS_HOST
            kubectl patch configmap mes-system-env --type json -p '[{"op": "remove", "path": "/data/REDIS_HOST"}]' 2>/dev/null || {
                echo "Warning: Could not remove REDIS_HOST from mes-system-env (it may not exist)"
            }
            # Remove REDIS_PORT
            kubectl patch configmap mes-system-env --type json -p '[{"op": "remove", "path": "/data/REDIS_PORT"}]' 2>/dev/null || {
                echo "Warning: Could not remove REDIS_PORT from mes-system-env (it may not exist)"
            }
        fi
    fi
fi

# Optionally remove Redis password from mes-system-secrets
if kubectl get secret mes-system-secrets &>/dev/null; then
    echo ""
    echo "Found mes-system-secrets. The Redis password can be removed."
    if [ "$1" != "--force" ]; then
        read -p "Remove REDIS_PASSWORD from mes-system-secrets? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Removing REDIS_PASSWORD from mes-system-secrets..."
            kubectl patch secret mes-system-secrets --type json -p '[{"op": "remove", "path": "/data/REDIS_PASSWORD"}]' 2>/dev/null || {
                echo "Warning: Could not remove REDIS_PASSWORD from mes-system-secrets (it may not exist)"
            }
        fi
    fi
fi