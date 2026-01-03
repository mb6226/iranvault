# Market Data Service Helm Chart

This Helm chart deploys the IranVault Market Data service, which provides real-time market data aggregation and WebSocket streaming for cryptocurrency trading.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- NATS messaging system
- Redis cache

## Installing the Chart

To install the chart with the release name `market-data`:

```bash
helm install market-data ./helm/market-data
```

## Uninstalling the Chart

To uninstall the `market-data` deployment:

```bash
helm uninstall market-data
```

## Configuration

The following table lists the configurable parameters of the market-data chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Image repository | `ghcr.io/mb6226/iranvault-market-data` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `replicaCount` | Number of replicas | `2` |
| `canary.enabled` | Enable canary deployment | `false` |
| `canary.weight` | Percentage of traffic to canary | `10` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `3000` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class | `""` |
| `ingress.hosts` | Ingress hosts | `[]` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `autoscaling.enabled` | Enable autoscaling | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `100` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization | `80` |
| `podDisruptionBudget.enabled` | Enable PDB | `false` |
| `podDisruptionBudget.minAvailable` | Minimum available pods | `1` |
| `networkPolicy.enabled` | Enable network policy | `false` |
| `env` | Environment variables | See values.yaml |

## Environment Variables

The service requires the following environment variables:

- `PORT`: Service port (default: 3000)
- `NATS_URL`: NATS server URL (default: nats://nats:4222)
- `REDIS_URL`: Redis server URL (default: redis://redis:6379)
- `LOG_LEVEL`: Logging level (default: info)
- `ENABLE_METRICS`: Enable Prometheus metrics (default: true)
- `NODE_ENV`: Node environment (production/staging)

## Canary Deployments

To enable canary deployments, set `canary.enabled` to `true` and configure the canary parameters:

```yaml
canary:
  enabled: true
  weight: 10  # Percentage of traffic to route to canary
  replicaCount: 1
  image:
    repository: ghcr.io/mb6226/iranvault-market-data
    tag: "canary"
```

## Autoscaling

To enable horizontal pod autoscaling:

```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

## Ingress

To enable ingress with TLS:

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: market-data.iranvault.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: market-data-tls
      hosts:
        - market-data.iranvault.com
```

## Security

The chart includes security best practices:

- Non-root user execution
- Read-only root filesystem
- Dropped capabilities
- Network policies
- Pod security contexts

## Monitoring

The service exposes Prometheus metrics at `/metrics` endpoint and includes health checks at `/health`.

## Testing

Run the included Helm tests:

```bash
helm test market-data
```

## CI/CD Integration

This chart is designed to work with the GitHub Actions CI/CD pipeline for automated deployments with canary rollouts.