# Changelog

All notable changes to the MES Redis Infrastructure project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-01-30

### Changed
- **BREAKING**: Changed namespace from dedicated `redis` to shared `mes-{environment}` namespace
- Updated all DNS references to use `redis-cluster.mes-{environment}.svc.cluster.local`
- Namespace creation handled by Kustomize overlays
- Applied Kubernetes standard labels (`app.kubernetes.io/*`) to all resources
- Added `restartForRedis: secrets` label for automatic pod restarts
- Added `system: mes` label to pod templates

## [1.0.2] - 2025-01-30

### Added
- REDIS_PORT to mes-system-env ConfigMap
- REDIS_PASSWORD to mes-system-secrets Secret
- Cleanup support for all Redis-related entries in system resources

### Changed
- Updated documentation to reflect new configuration entries

## [1.0.1] - 2025-01-30

### Added
- Integration with mes-system-env ConfigMap
- Automatic update of REDIS_HOST in mes-system-env during deployment
- Optional removal of REDIS_HOST from mes-system-env during cleanup

## [1.0.0] - 2025-01-30

### Added
- Initial release of MES Redis Infrastructure
- Kubernetes deployment using StatefulSet for data persistence
- Kustomize-based configuration management
- Support for three environments: localdev, staging, and production
- Environment-specific Redis configurations
- Automated secret management across namespaces
- Custom Dockerfile for Redis with configuration injection
- Deployment scripts: init.sh, build.sh, deploy.sh, clean.sh
- Comprehensive health checks (liveness and readiness probes)
- Persistent Volume Claims for data durability
- Error handling for CI/CD compatibility
- Comprehensive documentation in README.md

### Security
- Password-based authentication for all environments
- Secure password generation for non-local environments
- Protected mode enabled for staging and production

### Infrastructure
- Base manifests with common Kubernetes resources
- Environment-specific overlays with appropriate resource limits
- Configurable memory limits and persistence settings
- Support for both standalone Kustomize and kubectl integrated Kustomize