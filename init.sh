#!/bin/bash

# MES Redis Infrastructure - Initialization Script
# This script builds and deploys Redis to the MES Kubernetes cluster

set -e

# Set context to local Docker Desktop Kubernetes
kubectl config use-context docker-desktop || {
    echo "Error: Failed to set kubectl context to docker-desktop"
    echo "Please ensure Docker Desktop is running with Kubernetes enabled"
    exit 1
}

# Set default environment
ENVIRONMENT="${ENVIRONMENT:-localdev}"
# Use NAMESPACE env var if set, otherwise default to mes
NAMESPACE="${NAMESPACE:-mes}"

echo "========================================="
echo "MES Redis Infrastructure Deployment"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo ""

# Namespace will be created by deploy.sh if needed

# Generate a secure password for Redis if not provided
if [ -z "$REDIS_PASSWORD" ]; then
    if [ "$ENVIRONMENT" == "localdev" ]; then
        REDIS_PASSWORD="local_redis_password"
        echo "Using default local development password"
    else
        REDIS_PASSWORD=$(openssl rand -hex 32)
        echo "Generated secure Redis password"
    fi
fi

# Create or update the Redis secret
echo "Creating Redis secret..."
kubectl create secret generic redis-secret \
    --namespace=$NAMESPACE \
    --from-literal=password="$REDIS_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f - || true

# Also create secret in default namespace for other services
kubectl create secret generic redis-credentials \
    --namespace=default \
    --from-literal=host="redis-cluster.$NAMESPACE.svc.cluster.local" \
    --from-literal=port="6379" \
    --from-literal=password="$REDIS_PASSWORD" \
    --from-literal=provider="redis" \
    --from-literal=type="cache" \
    --dry-run=client -o yaml | kubectl apply -f - || true

# Create secret in mes namespace if it exists
kubectl get namespace mes &>/dev/null && {
    echo "Creating Redis credentials in mes namespace..."
    kubectl create secret generic redis-credentials \
        --namespace=mes \
        --from-literal=host="redis-cluster.$NAMESPACE.svc.cluster.local" \
        --from-literal=port="6379" \
        --from-literal=password="$REDIS_PASSWORD" \
        --from-literal=provider="redis" \
        --from-literal=type="cache" \
        --dry-run=client -o yaml | kubectl apply -f - || true
}

# Build the Docker image (only for local development)
if [ "$ENVIRONMENT" == "localdev" ]; then
    echo ""
    echo "Building Redis Docker image..."
    ./build.sh || {
        echo "Warning: Failed to build custom Redis image, will use default image"
    }
fi

# Deploy Redis
echo ""
echo "Deploying Redis to Kubernetes..."
./deploy.sh || {
    echo "Error: Failed to deploy Redis"
    exit 1
}

# Wait for Redis to be ready
echo ""
echo "Waiting for Redis to be ready..."
kubectl wait --namespace=$NAMESPACE \
    --for=condition=ready pod \
    --selector=app=redis,component=cache \
    --timeout=300s || {
    echo "Warning: Redis pod did not become ready in time"
    echo "Check pod status with: kubectl get pods -n $NAMESPACE"
}

# Display connection information
echo ""
echo "========================================="
echo "Redis deployment completed successfully!"
echo "========================================="
echo ""
echo "Connection Details:"
echo "  Internal DNS: redis-cluster.$NAMESPACE.svc.cluster.local"
echo "  Port: 6379"
echo "  Namespace: $NAMESPACE"
echo ""
echo "To connect from within the cluster:"
echo "  redis-cli -h redis-cluster.$NAMESPACE.svc.cluster.local -p 6379 -a <password>"
echo ""
echo "To port-forward for local access:"
echo "  kubectl port-forward -n $NAMESPACE svc/redis-cluster 6379:6379"
echo ""
echo "To check Redis status:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l app=redis"
echo ""

# Restart deployments that depend on Redis (if any)
echo "Restarting dependent services..."
kubectl rollout restart deployment --selector='restartForRedis=secrets' --namespace=default 2>/dev/null || true
kubectl rollout restart deployment --selector='restartForRedis=secrets' --namespace=mes 2>/dev/null || true

# Update mes-system-env configmap with Redis hostname and port
echo "Updating mes-system-env configmap with Redis connection details..."
REDIS_HOSTNAME="redis-cluster.$NAMESPACE.svc.cluster.local"
REDIS_PORT="6379"

# Check if mes-system-env configmap exists
if kubectl get configmap mes-system-env &>/dev/null; then
    echo "Found existing mes-system-env configmap, patching with Redis connection details..."
    # Patch the configmap to add/update REDIS_HOST and REDIS_PORT
    kubectl patch configmap mes-system-env --type merge -p "{\"data\":{\"REDIS_HOST\":\"$REDIS_HOSTNAME\",\"REDIS_PORT\":\"$REDIS_PORT\"}}" || {
        echo "Warning: Failed to patch mes-system-env configmap"
    }
else
    echo "mes-system-env configmap not found, creating it with Redis connection details..."
    kubectl create configmap mes-system-env \
        --from-literal=REDIS_HOST="$REDIS_HOSTNAME" \
        --from-literal=REDIS_PORT="$REDIS_PORT" \
        --from-literal=ENVIRONMENT=local || {
        echo "Warning: Failed to create mes-system-env configmap"
    }
fi

# Update mes-system-secrets secret with Redis password
echo "Updating mes-system-secrets with Redis password..."
# Check if mes-system-secrets exists
if kubectl get secret mes-system-secrets &>/dev/null; then
    echo "Found existing mes-system-secrets, patching with Redis password..."
    # Get current secret data
    CURRENT_DATA=$(kubectl get secret mes-system-secrets -o json | jq -r '.data // {}')
    # Add Redis password to the data
    REDIS_PASSWORD_BASE64=$(echo -n "$REDIS_PASSWORD" | base64)
    NEW_DATA=$(echo "$CURRENT_DATA" | jq --arg pass "$REDIS_PASSWORD_BASE64" '. + {"REDIS_PASSWORD": $pass}')
    # Patch the secret
    kubectl patch secret mes-system-secrets --type merge -p "{\"data\":$NEW_DATA}" || {
        echo "Warning: Failed to patch mes-system-secrets"
    }
else
    echo "mes-system-secrets not found, creating it with Redis password..."
    kubectl create secret generic mes-system-secrets \
        --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" || {
        echo "Warning: Failed to create mes-system-secrets"
    }
fi

echo "Redis infrastructure initialization complete!"