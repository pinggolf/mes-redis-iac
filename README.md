# MES Redis Infrastructure

This project provides Redis deployment infrastructure for the MES (Manufacturing Execution System) environment. It follows the standard MES deployment patterns and supports multiple environments with appropriate configurations.

## Overview

The MES Redis Infrastructure project deploys a Redis instance to Kubernetes with:
- Environment-specific configurations (localdev, staging, production)
- Persistent storage for data durability
- Secure password authentication
- Health checks and monitoring
- Automatic secret management
- Graceful error handling for CI/CD pipelines

## Quick Start

Deploy Redis to your local Kubernetes cluster:

```bash
./init.sh
```

This command will:
1. Set kubectl context to docker-desktop
2. Ensure the mes-{environment} namespace exists
3. Generate and store Redis credentials
4. Build the Docker image (local development only)
5. Deploy Redis using Kustomize
6. Wait for Redis to be ready
7. Display connection information

## Architecture

### Components

- **StatefulSet**: Manages Redis pods with persistent storage
- **Service**: Provides cluster-internal access to Redis
- **ConfigMap**: Stores Redis configuration
- **Secret**: Manages Redis authentication credentials
- **PersistentVolumeClaim**: Ensures data persistence across pod restarts

### Environments

The project supports three environments with different configurations:

#### Local Development (`localdev`)
- Single Redis instance
- Minimal resource requirements (128Mi memory)
- Persistence disabled for faster development
- Debug logging enabled
- Default password for convenience

#### Staging
- Single Redis instance with higher resources (512Mi memory)
- Persistence enabled with AOF (Append Only File)
- Standard logging
- Secure password generation

#### Production
- Single Redis instance with production resources (1Gi memory)
- Aggressive persistence settings
- AOF enabled with frequent fsync
- 10Gi persistent storage
- Optimized for reliability

## Scripts

### `init.sh`
Main initialization script that orchestrates the complete deployment:
- Sets up Kubernetes context
- Creates namespace and secrets
- Builds Docker image (local only)
- Deploys Redis
- Verifies deployment
- Shows connection details

### `build.sh`
Builds custom Redis Docker image:
- Uses Redis 7 Alpine base image
- Copies environment-specific configuration
- Only used in local development

### `deploy.sh`
Deploys Redis to Kubernetes:
- Uses Kustomize for manifest generation
- Supports multiple environments
- Applies manifests with overwrite flag

### `clean.sh`
Removes Redis deployment:
- Deletes all Kubernetes resources
- Removes secrets from all namespaces
- Cleans up PVCs
- Removes Redis entries from mes-system-env ConfigMap
- Removes Redis password from mes-system-secrets Secret
- Optionally removes empty namespace

## Configuration

### Environment Variables

- `ENVIRONMENT`: Target environment (localdev, staging, production) - default: localdev
- `NAMESPACE`: Kubernetes namespace - default: mes-{environment}
- `REDIS_PASSWORD`: Redis password - auto-generated if not provided
- `REGISTRY_NAME`: Docker registry name - default: mes-redis
- `IMAGE_NAME`: Docker image name - default: localdev

### Redis Configuration

Each environment has its own `redis.conf` with appropriate settings:

- **Memory Limits**: Configured per environment
- **Persistence**: Disabled in local, enabled in staging/production
- **AOF Settings**: Optimized for each environment
- **Logging**: Debug in local, notice in staging, warning in production
- **Security**: Password authentication required

## Usage

### Basic Deployment

```bash
# Deploy to local development
./init.sh

# Deploy to staging
ENVIRONMENT=staging ./init.sh

# Deploy to production
ENVIRONMENT=production REDIS_PASSWORD="secure-password" ./init.sh
```

### Connecting to Redis

#### From within the cluster:
```bash
redis-cli -h redis-cluster.mes-{environment}.svc.cluster.local -p 6379 -a <password>
```

#### Using port-forward:
```bash
kubectl port-forward -n mes-{environment} svc/redis-cluster 6379:6379
redis-cli -h localhost -p 6379 -a <password>
```

#### From application code:
```javascript
const redis = require('redis');
const client = redis.createClient({
  host: 'redis-cluster.mes-{environment}.svc.cluster.local',
  port: 6379,
  password: process.env.REDIS_PASSWORD
});
```

### Checking Status

```bash
# View Redis pods
kubectl get pods -n mes-{environment}

# Check Redis logs
kubectl logs -n mes-{environment} -l app=redis

# Get deployment status
kubectl get all -n mes-{environment} -l app=redis

# Test Redis connection
kubectl exec -it -n mes-{environment} redis-0 -- redis-cli -a <password> ping
```

### Cleanup

```bash
# Remove Redis deployment (non-interactive)
./clean.sh
```

The clean script automatically:
- Removes all Redis Kubernetes resources
- Cleans up Redis entries from mes-system-env ConfigMap
- Removes Redis password from mes-system-secrets Secret
- Deletes persistent volume claims
- Removes empty namespaces

## Secrets Management

The deployment creates secrets in multiple namespaces:

1. **redis-secret** (mes-{environment} namespace): Contains the Redis password
2. **redis-credentials** (default namespace): Connection details for services
3. **redis-credentials** (mes namespace): Connection details for MES services

Secret format:
```yaml
data:
  host: redis-cluster.mes-{environment}.svc.cluster.local
  port: "6379"
  password: <base64-encoded-password>
  provider: redis
  type: cache
```

## ConfigMap and Secret Integration

### ConfigMap (mes-system-env)

The deployment updates the `mes-system-env` ConfigMap with Redis connection details:

- **REDIS_HOST**: `redis-cluster.mes-{environment}.svc.cluster.local`
- **REDIS_PORT**: `6379`

### Secret (mes-system-secrets)

The deployment updates the `mes-system-secrets` Secret with:

- **REDIS_PASSWORD**: The Redis authentication password

### Usage in Applications

MES services can retrieve Redis configuration from these central resources:

```yaml
env:
  - name: REDIS_HOST
    valueFrom:
      configMapKeyRef:
        name: mes-system-env
        key: REDIS_HOST
  - name: REDIS_PORT
    valueFrom:
      configMapKeyRef:
        name: mes-system-env
        key: REDIS_PORT
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: mes-system-secrets
        key: REDIS_PASSWORD
```

## Error Handling

The scripts handle errors gracefully for CI/CD compatibility:

- Non-critical operations use `|| true` to continue execution
- Namespace creation uses `--dry-run=client` for idempotency
- Secret creation is idempotent with kubectl apply
- Deployment uses `--overwrite=true` flag
- Wait conditions have timeouts with warnings

## Monitoring and Health Checks

Redis pods include:
- **Liveness Probe**: Checks Redis responsiveness
- **Readiness Probe**: Ensures Redis is ready for connections
- Both probes use `redis-cli ping` with authentication

## Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod -n mes-{environment} redis-0
kubectl logs -n mes-{environment} redis-0
```

### Connection Issues
1. Verify secret exists: `kubectl get secret -n mes-{environment} redis-secret`
2. Check service: `kubectl get svc -n mes-{environment}`
3. Test connection: `kubectl exec -it -n mes-{environment} redis-0 -- redis-cli -a <password> ping`

### Performance Issues
1. Check resource usage: `kubectl top pod -n mes-{environment}`
2. Review Redis info: `kubectl exec -it -n mes-{environment} redis-0 -- redis-cli -a <password> info`
3. Check slow log: `kubectl exec -it -n mes-{environment} redis-0 -- redis-cli -a <password> slowlog get`

### Persistence Issues
1. Verify PVC: `kubectl get pvc -n mes-{environment}`
2. Check AOF status: `kubectl exec -it -n mes-{environment} redis-0 -- redis-cli -a <password> info persistence`

## Integration with MES Services

MES services can access Redis using the created secrets:

```yaml
env:
  - name: REDIS_HOST
    valueFrom:
      secretKeyRef:
        name: redis-credentials
        key: host
  - name: REDIS_PORT
    valueFrom:
      secretKeyRef:
        name: redis-credentials
        key: port
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-credentials
        key: password
```

## Production Considerations

1. **Backup Strategy**: Implement regular backups of Redis data
2. **Monitoring**: Set up Prometheus metrics collection
3. **High Availability**: Consider Redis Sentinel or Cluster for HA
4. **Security**: Use strong passwords and network policies
5. **Resource Limits**: Adjust based on actual usage patterns

## Future Enhancements

- [ ] Redis Cluster support for horizontal scaling
- [ ] Prometheus metrics exporter
- [ ] Automated backup solution
- [ ] TLS/SSL encryption
- [ ] Redis Sentinel for high availability
- [ ] Grafana dashboards
- [ ] Performance tuning scripts

## Contributing

When making changes:
1. Test in local development first
2. Update environment-specific configurations as needed
3. Document any new environment variables
4. Ensure scripts remain idempotent
5. Maintain CI/CD compatibility with proper error handling

## License

This project is part of the MES Environment and follows the same licensing terms.