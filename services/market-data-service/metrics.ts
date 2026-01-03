// Market Data Service Metrics
import client from 'prom-client'

// Collect default metrics (CPU, memory, etc.)
client.collectDefaultMetrics()

// HTTP request duration histogram
export const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5, 10]
})

// WebSocket connections gauge
export const websocketConnections = new client.Gauge({
  name: 'websocket_connections_total',
  help: 'Number of active WebSocket connections'
})

// NATS messages processed counter
export const natsMessagesProcessed = new client.Counter({
  name: 'nats_messages_processed_total',
  help: 'Total number of NATS messages processed',
  labelNames: ['subject']
})

// Redis operations counter
export const redisOperations = new client.Counter({
  name: 'redis_operations_total',
  help: 'Total number of Redis operations',
  labelNames: ['operation', 'status']
})

// Trade events broadcast counter
export const tradeEventsBroadcast = new client.Counter({
  name: 'trade_events_broadcast_total',
  help: 'Total number of trade events broadcast to WebSocket clients'
})

// Orderbook updates counter
export const orderbookUpdates = new client.Counter({
  name: 'orderbook_updates_total',
  help: 'Total number of orderbook updates processed'
})

// Ticker updates counter
export const tickerUpdates = new client.Counter({
  name: 'ticker_updates_total',
  help: 'Total number of ticker updates processed'
})

// Export the register for /metrics endpoint
export { client }