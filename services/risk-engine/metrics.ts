// Risk Engine Metrics
import client from 'prom-client'

// Collect default metrics
client.collectDefaultMetrics()

// HTTP request duration histogram
export const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5, 10]
})

// Order validation counter
export const ordersValidated = new client.Counter({
  name: 'orders_validated_total',
  help: 'Total number of orders validated',
  labelNames: ['result'] // approved, rejected
})

// Risk check duration histogram
export const riskCheckDuration = new client.Histogram({
  name: 'risk_check_duration_seconds',
  help: 'Duration of risk checks in seconds',
  labelNames: ['result'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2]
})

// NATS messages processed counter
export const natsMessagesProcessed = new client.Counter({
  name: 'nats_messages_processed_total',
  help: 'Total number of NATS messages processed',
  labelNames: ['subject']
})

// Fund lock operations counter
export const fundLockOperations = new client.Counter({
  name: 'fund_lock_operations_total',
  help: 'Total number of fund lock/unlock operations',
  labelNames: ['operation', 'status'] // lock, unlock
})

// Liquidation events counter
export const liquidationsTriggered = new client.Counter({
  name: 'liquidations_triggered_total',
  help: 'Total number of liquidations triggered'
})

// Kill switch status gauge
export const killSwitchStatus = new client.Gauge({
  name: 'kill_switch_status',
  help: 'Kill switch status (1 = active, 0 = inactive)'
})

// Circuit breaker status gauge
export const circuitBreakerStatus = new client.Gauge({
  name: 'circuit_breaker_status',
  help: 'Circuit breaker status (1 = tripped, 0 = normal)'
})

// Rejection rate gauge
export const rejectionRate = new client.Gauge({
  name: 'rejection_rate_per_minute',
  help: 'Current rejection rate per minute'
})

// Export the register
export { client }