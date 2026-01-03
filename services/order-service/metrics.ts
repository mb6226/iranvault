// Order Service Metrics
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

// Orders created counter
export const ordersCreated = new client.Counter({
  name: 'orders_created_total',
  help: 'Total number of orders created',
  labelNames: ['status'] // pending, approved, rejected, timeout
})

// Order processing duration histogram
export const orderProcessingDuration = new client.Histogram({
  name: 'order_processing_duration_seconds',
  help: 'Duration of order processing from creation to final response',
  labelNames: ['result'],
  buckets: [0.1, 0.5, 1, 2, 5, 10, 30]
})

// NATS messages processed counter
export const natsMessagesProcessed = new client.Counter({
  name: 'nats_messages_processed_total',
  help: 'Total number of NATS messages processed',
  labelNames: ['subject']
})

// Active pending orders gauge
export const pendingOrders = new client.Gauge({
  name: 'pending_orders_total',
  help: 'Number of orders currently pending risk validation'
})

// Export the register
export { client }