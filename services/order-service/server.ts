// IranVault Order Service
// Order management with risk validation integration

import { connect, NatsConnection, StringCodec } from 'nats'
import express from 'express'
import cors from 'cors'
import { v4 as uuidv4 } from 'uuid'
import { client, httpRequestDuration, ordersCreated, orderProcessingDuration, natsMessagesProcessed, pendingOrders } from './metrics'

const PORT = process.env.PORT || 3000
const NATS_URL = process.env.NATS_URL || 'nats://nats:4222'

interface OrderRequest {
  userId: string
  symbol: string
  side: 'BUY' | 'SELL'
  price: number
  quantity: number
  type: 'LIMIT' | 'MARKET'
  leverage?: number
}

interface OrderResponse {
  orderId: string
  status: 'pending' | 'approved' | 'rejected'
  reason?: string
}

class OrderService {
  private nats: NatsConnection | null = null
  private app: express.Application
  private pendingOrders: Map<string, { resolve: Function, reject: Function, timeout: NodeJS.Timeout }> = new Map()

  constructor() {
    this.app = express()
    this.app.use(cors())
    this.app.use(express.json())
    this.setupRoutes()
  }

  async start() {
    console.log('Starting Order Service...')

    // Connect to NATS
    try {
      this.nats = await connect({ servers: NATS_URL })
      console.log('Connected to NATS')
    } catch (error) {
      console.error('Failed to connect to NATS:', error)
      process.exit(1)
    }

    // Subscribe to responses
    this.subscribeToResponses()

    // Start HTTP server
    this.app.listen(PORT, () => {
      console.log(`Order Service listening on port ${PORT}`)
    })
  }

  private setupRoutes() {
    this.app.post('/orders', async (req, res) => {
      const end = httpRequestDuration.startTimer({ method: req.method, route: '/orders' })
      const processingEnd = orderProcessingDuration.startTimer()
      try {
        const orderReq: OrderRequest = req.body
        const orderId = uuidv4()

        ordersCreated.inc({ status: 'pending' })
        pendingOrders.inc()

        // Create order promise
        const orderPromise = new Promise<OrderResponse>((resolve, reject) => {
          const timeout = setTimeout(() => {
            this.pendingOrders.delete(orderId)
            pendingOrders.dec()
            ordersCreated.inc({ status: 'timeout' })
            processingEnd({ result: 'timeout' })
            reject(new Error('Order validation timeout'))
          }, 30000) // 30 second timeout

          this.pendingOrders.set(orderId, { resolve, reject, timeout })
        })

        // Publish order.created
        await this.publishOrderCreated(orderId, orderReq)

        // Wait for response
        const result = await orderPromise

        ordersCreated.inc({ status: result.status })
        processingEnd({ result: result.status })

        res.json(result)
        end({ status_code: res.statusCode.toString() })
      } catch (error) {
        ordersCreated.inc({ status: 'error' })
        processingEnd({ result: 'error' })
        console.error('Error creating order:', error)
        res.status(500).json({ error: 'Failed to create order' })
        end({ status_code: res.statusCode.toString() })
      }
    })

    this.app.get('/health', (req, res) => {
      const end = httpRequestDuration.startTimer({ method: req.method, route: '/health' })
      res.json({ status: 'ok', timestamp: Date.now() })
      end({ status_code: res.statusCode.toString() })
    })

    // Metrics endpoint
    this.app.get('/metrics', async (req, res) => {
      res.set('Content-Type', client.register.contentType)
      res.end(await client.register.metrics())
    })
  }

  private async publishOrderCreated(orderId: string, order: OrderRequest) {
    if (!this.nats) return

    const sc = StringCodec()
    const event = {
      orderId,
      userId: order.userId,
      symbol: order.symbol,
      side: order.side,
      price: order.price,
      quantity: order.quantity,
      type: order.type,
      leverage: order.leverage || 1,
      timestamp: Date.now()
    }

    this.nats.publish('orders.created', sc.encode(JSON.stringify(event)))
  }

  private subscribeToResponses() {
    if (!this.nats) return

    const sc = StringCodec()

    // Subscribe to orders.approved
    const approvedSub = this.nats.subscribe('orders.approved')
    ;(async () => {
      for await (const msg of approvedSub) {
        try {
          natsMessagesProcessed.inc({ subject: 'orders.approved' })
          const approved = JSON.parse(sc.decode(msg.data))
          this.handleOrderApproved(approved)
        } catch (error) {
          console.error('Error processing orders.approved:', error)
        }
      }
    })()

    // Subscribe to orders.rejected
    const rejectedSub = this.nats.subscribe('orders.rejected')
    ;(async () => {
      for await (const msg of rejectedSub) {
        try {
          natsMessagesProcessed.inc({ subject: 'orders.rejected' })
          const rejected = JSON.parse(sc.decode(msg.data))
          this.handleOrderRejected(rejected)
        } catch (error) {
          console.error('Error processing orders.rejected:', error)
        }
      }
    })()
  }

  private handleOrderApproved(approved: any) {
    const pending = this.pendingOrders.get(approved.orderId)
    if (pending) {
      clearTimeout(pending.timeout)
      this.pendingOrders.delete(approved.orderId)
      pendingOrders.dec()
      pending.resolve({
        orderId: approved.orderId,
        status: 'approved'
      })

      // Forward to matching engine (publish to orders.matched or something)
      this.forwardToMatchingEngine(approved)
    }
  }

  private handleOrderRejected(rejected: any) {
    const pending = this.pendingOrders.get(rejected.orderId)
    if (pending) {
      clearTimeout(pending.timeout)
      this.pendingOrders.delete(rejected.orderId)
      pendingOrders.dec()
      pending.reject(new Error(rejected.reason || 'Order rejected'))
    }
  }

  private async forwardToMatchingEngine(approved: any) {
    if (!this.nats) return

    // Publish to a subject that matching engine subscribes to
    const sc = StringCodec()
    this.nats.publish('orders.to_match', sc.encode(JSON.stringify(approved)))
  }

  async stop() {
    console.log('Stopping Order Service...')

    if (this.nats) {
      await this.nats.close()
    }
  }
}

// Start the service
const service = new OrderService()

process.on('SIGINT', async () => {
  await service.stop()
  process.exit(0)
})

process.on('SIGTERM', async () => {
  await service.stop()
  process.exit(0)
})

service.start().catch(console.error)