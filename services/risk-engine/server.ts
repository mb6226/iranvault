// IranVault Risk Engine
// Real-time risk management and fund locking

import { connect, NatsConnection, StringCodec } from 'nats'
import { createClient, RedisClientType } from 'redis'
import express from 'express'
import cors from 'cors'
import { createServer } from 'http'
import * as fs from 'fs'
import * as yaml from 'js-yaml'
import { client, httpRequestDuration, ordersValidated, riskCheckDuration, natsMessagesProcessed, fundLockOperations, liquidationsTriggered, killSwitchStatus, circuitBreakerStatus, rejectionRate } from './metrics'

const PORT = process.env.PORT || 3000
const NATS_URL = process.env.NATS_URL || 'nats://nats:4222'
const REDIS_URL = process.env.REDIS_URL || 'redis://redis:6379'

interface RiskRules {
  maxOrderSize: { [symbol: string]: number }
  maxExposure: { [symbol: string]: number }
  maxLeverage: number
  maintenanceMargin: number
  liquidationMargin: number
  killSwitch: boolean
  circuitBreaker: {
    maxRejectionsPerMinute: number
    timeoutSeconds: number
  }
}

interface OrderCreatedEvent {
  orderId: string
  userId: string
  symbol: string
  side: 'BUY' | 'SELL'
  price: number
  quantity: number
  type: string
  leverage?: number
}

interface WalletUpdatedEvent {
  userId: string
  asset: string
  balance: number
  locked: number
}

interface PricesUpdatedEvent {
  symbol: string
  price: number
  timestamp: number
}

interface UserBalance {
  free: number
  locked: number
}

interface UserPosition {
  userId: string
  symbol: string
  size: number
  entryPrice: number
  leverage: number
}

class RiskEngine {
  private nats: NatsConnection | null = null
  private redis: RedisClientType | null = null
  private app: express.Application
  private server: any
  private rules: RiskRules = {
    maxOrderSize: {},
    maxExposure: {},
    maxLeverage: 3,
    maintenanceMargin: 0.005,
    liquidationMargin: 0.003,
    killSwitch: false,
    circuitBreaker: { maxRejectionsPerMinute: 100, timeoutSeconds: 300 }
  }
  private rejectionCount: number = 0
  private lastRejectionReset: number = Date.now()

  constructor() {
    this.app = express()
    this.app.use(cors())
    this.setupRoutes()
    this.loadRiskRules()
  }

  private loadRiskRules() {
    try {
      const fileContents = fs.readFileSync('./risk-rules.yaml', 'utf8')
      this.rules = yaml.load(fileContents) as RiskRules
      console.log('Loaded risk rules:', this.rules)
    } catch (error) {
      console.error('Failed to load risk rules:', error)
      // Default rules
      this.rules = {
        maxOrderSize: { 'BTC-USDT': 1, 'BNB-PERP': 10 },
        maxExposure: { 'BTC-USDT': 5, 'BNB-PERP': 50 },
        maxLeverage: 3,
        maintenanceMargin: 0.005,
        liquidationMargin: 0.003,
        killSwitch: false,
        circuitBreaker: { maxRejectionsPerMinute: 100, timeoutSeconds: 300 }
      }
    }
  }

  async start() {
    console.log('Starting Risk Engine...')

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

    // Start HTTP server
    this.startServer()

    console.log(`Risk Engine started on port ${PORT}`)
  }

  private setupRoutes() {
    this.app.get('/health', (req, res) => {
      const end = httpRequestDuration.startTimer({ method: req.method, route: '/health' })
      killSwitchStatus.set(this.rules.killSwitch ? 1 : 0)
      circuitBreakerStatus.set(this.rejectionCount > this.rules.circuitBreaker.maxRejectionsPerMinute ? 1 : 0)
      rejectionRate.set(this.rejectionCount)
      res.json({
        status: 'ok',
        timestamp: Date.now(),
        killSwitch: this.rules.killSwitch,
        rejectionCount: this.rejectionCount
      })
      end({ status_code: res.statusCode.toString() })
    })

    this.app.get('/rules', (req, res) => {
      const end = httpRequestDuration.startTimer({ method: req.method, route: '/rules' })
      res.json(this.rules)
      end({ status_code: res.statusCode.toString() })
    })

    this.app.post('/kill-switch/:state', (req, res) => {
      const end = httpRequestDuration.startTimer({ method: req.method, route: '/kill-switch' })
      const state = req.params.state === 'true'
      this.rules.killSwitch = state
      killSwitchStatus.set(state ? 1 : 0)
      res.json({ killSwitch: this.rules.killSwitch })
      end({ status_code: res.statusCode.toString() })
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

    // Subscribe to order.created
    const orderSub = this.nats.subscribe('orders.created')
    ;(async () => {
      for await (const msg of orderSub) {
        try {
          natsMessagesProcessed.inc({ subject: 'orders.created' })
          const order: OrderCreatedEvent = JSON.parse(sc.decode(msg.data))
          await this.handleOrderCreated(order)
        } catch (error) {
          console.error('Error processing order.created:', error)
        }
      }
    })()

    // Subscribe to wallet.updated
    const walletSub = this.nats.subscribe('wallet.updated')
    ;(async () => {
      for await (const msg of walletSub) {
        try {
          natsMessagesProcessed.inc({ subject: 'wallet.updated' })
          const wallet: WalletUpdatedEvent = JSON.parse(sc.decode(msg.data))
          await this.handleWalletUpdated(wallet)
        } catch (error) {
          console.error('Error processing wallet.updated:', error)
        }
      }
    })()

    // Subscribe to prices.updated
    const pricesSub = this.nats.subscribe('prices.updated')
    ;(async () => {
      for await (const msg of pricesSub) {
        try {
          natsMessagesProcessed.inc({ subject: 'prices.updated' })
          const prices: PricesUpdatedEvent = JSON.parse(sc.decode(msg.data))
          await this.handlePricesUpdated(prices)
        } catch (error) {
          console.error('Error processing prices.updated:', error)
        }
      }
    })()
  }

  private async handleOrderCreated(order: OrderCreatedEvent) {
    console.log('Processing order:', order.orderId)
    const end = riskCheckDuration.startTimer()

    // Check kill switch
    if (this.rules.killSwitch) {
      ordersValidated.inc({ result: 'rejected' })
      end({ result: 'rejected' })
      await this.rejectOrder(order.orderId, 'KILL_SWITCH_ACTIVE')
      return
    }

    // Check circuit breaker
    this.checkCircuitBreaker()

    try {
      // Get user balance
      const balance = await this.getUserBalance(order.userId, order.symbol.split('-')[1] || 'USDT')
      const requiredFunds = order.price * order.quantity

      // Balance check
      if (balance.free < requiredFunds) {
        ordersValidated.inc({ result: 'rejected' })
        end({ result: 'rejected' })
        await this.rejectOrder(order.orderId, 'INSUFFICIENT_BALANCE')
        return
      }

      // Exposure check
      const exposure = await this.getUserExposure(order.userId, order.symbol)
      const maxExposure = this.rules.maxExposure[order.symbol] || 10
      if (exposure + order.quantity > maxExposure) {
        ordersValidated.inc({ result: 'rejected' })
        end({ result: 'rejected' })
        await this.rejectOrder(order.orderId, 'EXPOSURE_LIMIT_EXCEEDED')
        return
      }

      // Leverage check
      if (order.leverage && order.leverage > this.rules.maxLeverage) {
        ordersValidated.inc({ result: 'rejected' })
        end({ result: 'rejected' })
        await this.rejectOrder(order.orderId, 'LEVERAGE_LIMIT_EXCEEDED')
        return
      }

      // Order size check
      const maxOrderSize = this.rules.maxOrderSize[order.symbol] || 1
      if (order.quantity > maxOrderSize) {
        ordersValidated.inc({ result: 'rejected' })
        end({ result: 'rejected' })
        await this.rejectOrder(order.orderId, 'ORDER_SIZE_LIMIT_EXCEEDED')
        return
      }

      // Lock funds
      await this.lockFunds(order.userId, order.symbol.split('-')[1] || 'USDT', requiredFunds)

      // Approve order
      await this.approveOrder(order.orderId, requiredFunds)

      ordersValidated.inc({ result: 'approved' })
      end({ result: 'approved' })

    } catch (error) {
      console.error('Error in risk check:', error)
      ordersValidated.inc({ result: 'error' })
      end({ result: 'error' })
      await this.rejectOrder(order.orderId, 'RISK_CHECK_ERROR')
    }
  }

  private async handleWalletUpdated(wallet: WalletUpdatedEvent) {
    // Update cached balance
    const key = `balance:${wallet.userId}:${wallet.asset}`
    await this.redis?.set(key, JSON.stringify({
      free: wallet.balance - wallet.locked,
      locked: wallet.locked
    }))
  }

  private async handlePricesUpdated(prices: PricesUpdatedEvent) {
    // Check for liquidations
    await this.checkLiquidations(prices.symbol, prices.price)
  }

  private async getUserBalance(userId: string, asset: string): Promise<UserBalance> {
    const key = `balance:${userId}:${asset}`
    const cached = await this.redis?.get(key)
    if (cached) {
      return JSON.parse(cached)
    }
    // Default balance if not cached
    return { free: 10000, locked: 0 } // TODO: fetch from wallet service
  }

  private async getUserExposure(userId: string, symbol: string): Promise<number> {
    const key = `exposure:${userId}:${symbol}`
    const cached = await this.redis?.get(key)
    return cached ? parseFloat(cached) : 0
  }

  private async lockFunds(userId: string, asset: string, amount: number) {
    if (!this.nats) return

    const sc = StringCodec()
    const event = {
      userId,
      asset,
      amount,
      orderId: 'pending', // Will be set by order service
      timestamp: Date.now()
    }
    this.nats.publish('funds.lock', sc.encode(JSON.stringify(event)))
    fundLockOperations.inc({ operation: 'lock', status: 'success' })
  }

  private async approveOrder(orderId: string, lockedFunds: number) {
    if (!this.nats) return

    const sc = StringCodec()
    const event = {
      orderId,
      riskId: `r${Date.now()}`,
      lockedFunds,
      timestamp: Date.now()
    }
    this.nats.publish('orders.approved', sc.encode(JSON.stringify(event)))
  }

  private async rejectOrder(orderId: string, reason: string) {
    if (!this.nats) return

    this.rejectionCount++

    const sc = StringCodec()
    const event = {
      orderId,
      reason,
      timestamp: Date.now()
    }
    this.nats.publish('orders.rejected', sc.encode(JSON.stringify(event)))
  }

  private checkCircuitBreaker() {
    const now = Date.now()
    if (now - this.lastRejectionReset > 60000) { // Reset every minute
      this.rejectionCount = 0
      this.lastRejectionReset = now
    }

    if (this.rejectionCount > this.rules.circuitBreaker.maxRejectionsPerMinute) {
      console.warn('Circuit breaker activated')
      this.rules.killSwitch = true
      setTimeout(() => {
        this.rules.killSwitch = false
        console.log('Circuit breaker reset')
      }, this.rules.circuitBreaker.timeoutSeconds * 1000)
    }
  }

  private async checkLiquidations(symbol: string, price: number) {
    // Get all positions for this symbol
    const positionsKey = `positions:${symbol}`
    const positionsStr = await this.redis?.get(positionsKey)
    if (!positionsStr) return

    const positions: UserPosition[] = JSON.parse(positionsStr)

    for (const position of positions) {
      const marginRatio = this.calculateMarginRatio(position, price)
      if (marginRatio < this.rules.liquidationMargin) {
        await this.liquidatePosition(position)
      }
    }
  }

  private calculateMarginRatio(position: UserPosition, currentPrice: number): number {
    // Simplified margin calculation
    const pnl = (currentPrice - position.entryPrice) * position.size * position.leverage
    const equity = 1000 + pnl // Assume initial equity
    const maintenanceMargin = equity * this.rules.maintenanceMargin
    return maintenanceMargin / equity
  }

  private async liquidatePosition(position: UserPosition) {
    if (!this.nats) return

    const sc = StringCodec()
    const event = {
      userId: position.userId || 'unknown',
      symbol: position.symbol,
      size: position.size,
      reason: 'LIQUIDATION',
      timestamp: Date.now()
    }
    this.nats.publish('positions.liquidate', sc.encode(JSON.stringify(event)))
    liquidationsTriggered.inc()
  }

  private startServer() {
    this.server = createServer(this.app)
    this.server.listen(PORT, () => {
      console.log(`HTTP server listening on port ${PORT}`)
    })
  }

  async stop() {
    console.log('Stopping Risk Engine...')

    if (this.nats) {
      await this.nats.close()
    }

    if (this.redis) {
      await this.redis.disconnect()
    }

    if (this.server) {
      this.server.close()
    }
  }
}

// Start the service
const engine = new RiskEngine()

process.on('SIGINT', async () => {
  await engine.stop()
  process.exit(0)
})

process.on('SIGTERM', async () => {
  await engine.stop()
  process.exit(0)
})

engine.start().catch(console.error)