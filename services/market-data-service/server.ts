// IranVault Market Data Service
// Real-time market data via WebSocket with Redis caching

import { connect, NatsConnection, StringCodec } from 'nats'
import { createClient, RedisClientType } from 'redis'
import { WebSocketServer, WebSocket } from 'ws'
import express from 'express'
import cors from 'cors'
import { createServer } from 'http'
import { client, httpRequestDuration, websocketConnections, natsMessagesProcessed, redisOperations, tradeEventsBroadcast, orderbookUpdates, tickerUpdates } from './metrics'

const PORT = process.env.PORT || 3000
const NATS_URL = process.env.NATS_URL || 'nats://nats:4222'
const REDIS_URL = process.env.REDIS_URL || 'redis://redis:6379'

interface Trade {
  id: string
  price: number
  amount: number
  maker: string
  taker: string
  ts: number
}

interface OrderBookEntry {
  price: number
  amount: number
}

interface OrderBook {
  bids: OrderBookEntry[]
  asks: OrderBookEntry[]
}

interface Ticker {
  symbol: string
  lastPrice: number
  volume24h: number
  high24h: number
  low24h: number
  ts: number
}

class MarketDataService {
  private nats: NatsConnection | null = null
  private redis: RedisClientType | null = null
  private wss: WebSocketServer | null = null
  private clients: Set<WebSocket> = new Set()
  private app: express.Application
  private server: any

  constructor() {
    this.app = express()
    this.app.use(cors())
    this.setupRoutes()
  }

  async start() {
    console.log('Starting Market Data Service...')

    // Connect to NATS
    try {
      this.nats = await connect({ servers: NATS_URL })
      console.log('Connected to NATS')
    } catch (error) {
      console.error('Failed to connect to NATS:', error)
      process.exit(1)
    }

    // Connect to Redis
    try {
      this.redis = createClient({ url: REDIS_URL })
      await this.redis.connect()
      console.log('Connected to Redis')
    } catch (error) {
      console.error('Failed to connect to Redis:', error)
      process.exit(1)
    }

    // Subscribe to NATS events
    this.subscribeToEvents()

    // Start HTTP/WebSocket server
    this.startServer()

    console.log(`Market Data Service started on port ${PORT}`)
  }

  private setupRoutes() {
    this.app.get('/health', (req, res) => {
      const end = httpRequestDuration.startTimer({ method: req.method, route: '/health' })
      res.json({ status: 'ok', timestamp: Date.now() })
      end({ status_code: res.statusCode.toString() })
    })

    this.app.get('/api/trades', async (req, res) => {
      const end = httpRequestDuration.startTimer({ method: req.method, route: '/api/trades' })
      try {
        const trades = await this.redis?.lRange('recent_trades', 0, 49) || []
        res.json(trades.map(t => JSON.parse(t)).reverse())
        end({ status_code: res.statusCode.toString() })
      } catch (error) {
        res.status(500).json({ error: 'Failed to fetch trades' })
        end({ status_code: res.statusCode.toString() })
      }
    })

    this.app.get('/api/orderbook', async (req, res) => {
      const end = httpRequestDuration.startTimer({ method: req.method, route: '/api/orderbook' })
      try {
        const orderbookStr = await this.redis?.get('orderbook')
        if (orderbookStr) {
          res.json(JSON.parse(orderbookStr))
        } else {
          res.json({ bids: [], asks: [] })
        }
        end({ status_code: res.statusCode.toString() })
      } catch (error) {
        res.status(500).json({ error: 'Failed to fetch orderbook' })
        end({ status_code: res.statusCode.toString() })
      }
    })

    // Metrics endpoint
    this.app.get('/metrics', async (req, res) => {
      res.set('Content-Type', client.register.contentType)
      res.end(await client.register.metrics())
    })
  }

  private subscribeToEvents() {
    if (!this.nats) return

    const sc = StringCodec()

    // Subscribe to trades
    const tradesSub = this.nats.subscribe('trades')
    ;(async () => {
      for await (const msg of tradesSub) {
        try {
          natsMessagesProcessed.inc({ subject: 'trades' })
          const trade: Trade = JSON.parse(sc.decode(msg.data))
          await this.handleTrade(trade)
        } catch (error) {
          console.error('Error processing trade:', error)
        }
      }
    })()

    // Subscribe to orderbook updates
    const orderbookSub = this.nats.subscribe('orderbook')
    ;(async () => {
      for await (const msg of orderbookSub) {
        try {
          natsMessagesProcessed.inc({ subject: 'orderbook' })
          const orderbook: OrderBook = JSON.parse(sc.decode(msg.data))
          await this.handleOrderBookUpdate(orderbook)
        } catch (error) {
          console.error('Error processing orderbook:', error)
        }
      }
    })()

    // Subscribe to ticker updates
    const tickerSub = this.nats.subscribe('ticker')
    ;(async () => {
      for await (const msg of tickerSub) {
        try {
          natsMessagesProcessed.inc({ subject: 'ticker' })
          const ticker: Ticker = JSON.parse(sc.decode(msg.data))
          await this.handleTickerUpdate(ticker)
        } catch (error) {
          console.error('Error processing ticker:', error)
        }
      }
    })()
  }

  private async handleTrade(trade: Trade) {
    // Cache recent trades in Redis
    const key = 'recent_trades'
    await this.redis?.lPush(key, JSON.stringify(trade))
    await this.redis?.lTrim(key, 0, 99) // Keep last 100 trades

    // Broadcast to WebSocket clients
    this.broadcast('trade', trade)
    tradeEventsBroadcast.inc()
  }

  private async handleOrderBookUpdate(orderbook: OrderBook) {
    // Cache orderbook in Redis
    await this.redis?.set('orderbook', JSON.stringify(orderbook))

    // Broadcast to WebSocket clients
    this.broadcast('orderbook', orderbook)
    orderbookUpdates.inc()
  }

  private async handleTickerUpdate(ticker: Ticker) {
    // Cache ticker in Redis
    await this.redis?.set(`ticker:${ticker.symbol}`, JSON.stringify(ticker))

    // Broadcast to WebSocket clients
    this.broadcast('ticker', ticker)
    tickerUpdates.inc()
  }

  private startServer() {
    this.server = createServer(this.app)
    this.wss = new WebSocketServer({ server: this.server })

    this.wss.on('connection', (ws: WebSocket) => {
      console.log('WebSocket client connected')
      websocketConnections.inc()
      this.clients.add(ws)

      // Send initial data
      this.sendInitialData(ws)

      ws.on('close', () => {
        console.log('WebSocket client disconnected')
        websocketConnections.dec()
        this.clients.delete(ws)
      })

      ws.on('error', (error) => {
        console.error('WebSocket error:', error)
        websocketConnections.dec()
        this.clients.delete(ws)
      })
    })

    this.server.listen(PORT, () => {
      console.log(`HTTP/WebSocket server listening on port ${PORT}`)
    })
  }

  private async sendInitialData(ws: WebSocket) {
    try {
      // Send recent trades
      const recentTrades = await this.redis?.lRange('recent_trades', 0, 9) || []
      if (recentTrades.length > 0) {
        ws.send(JSON.stringify({
          type: 'recent_trades',
          data: recentTrades.map(t => JSON.parse(t)).reverse()
        }))
      }

      // Send current orderbook
      const orderbookStr = await this.redis?.get('orderbook')
      if (orderbookStr) {
        ws.send(JSON.stringify({
          type: 'orderbook',
          data: JSON.parse(orderbookStr)
        }))
      }

      // Send current ticker
      const tickerKeys = await this.redis?.keys('ticker:*') || []
      for (const key of tickerKeys) {
        const tickerStr = await this.redis?.get(key)
        if (tickerStr) {
          ws.send(JSON.stringify({
            type: 'ticker',
            data: JSON.parse(tickerStr)
          }))
        }
      }
    } catch (error) {
      console.error('Error sending initial data:', error)
    }
  }

  private broadcast(type: string, data: any) {
    const message = JSON.stringify({ type, data })
    this.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message)
      }
    })
  }

  async stop() {
    console.log('Stopping Market Data Service...')

    if (this.nats) {
      await this.nats.close()
    }

    if (this.redis) {
      await this.redis.disconnect()
    }

    if (this.wss) {
      this.wss.close()
    }

    if (this.server) {
      this.server.close()
    }
  }
}

// Start the service
const service = new MarketDataService()

process.on('SIGINT', async () => {
  await service.stop()
  process.exit(0)
})

process.on('SIGTERM', async () => {
  await service.stop()
  process.exit(0)
})

service.start().catch(console.error)