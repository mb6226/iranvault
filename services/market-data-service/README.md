# IranVault Market Data Service

Real-time market data service that aggregates and broadcasts trading data via WebSocket with Redis caching.

## Features

- **Real-time WebSocket Broadcasting**: Live trade updates, order book changes, and ticker data
- **Redis Caching**: High-performance caching for market data
- **NATS Event Streaming**: Subscribes to trading events from the matching engine
- **REST API**: HTTP endpoints for historical data and health checks

## Architecture

The service connects to:
- **NATS**: For consuming trade events, order book updates, and ticker data
- **Redis**: For caching recent trades, current order book, and ticker information
- **WebSocket**: For broadcasting real-time data to connected clients

## API Endpoints

### HTTP API

- `GET /health` - Health check
- `GET /api/trades` - Recent trades (last 50)
- `GET /api/orderbook` - Current order book

### WebSocket API

Connect to `ws://localhost:8081` to receive real-time updates:

```javascript
const ws = new WebSocket('ws://localhost:8081')

ws.onmessage = (event) => {
  const message = JSON.parse(event.data)
  switch (message.type) {
    case 'trade':
      console.log('New trade:', message.data)
      break
    case 'orderbook':
      console.log('Order book update:', message.data)
      break
    case 'ticker':
      console.log('Ticker update:', message.data)
      break
    case 'recent_trades':
      console.log('Recent trades:', message.data)
      break
  }
}
```

## Environment Variables

- `PORT`: HTTP server port (default: 8080)
- `WS_PORT`: WebSocket server port (default: 8081)
- `NATS_URL`: NATS server URL (default: nats://nats:4222)
- `REDIS_URL`: Redis server URL (default: redis://redis:6379)

## Development

```bash
npm install
npm run dev
```

## Production

```bash
npm run build
npm start
```