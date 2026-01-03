// Quick test for vault events
const WebSocket = require('ws')

console.log('🔌 Testing WebSocket connection...')
const ws = new WebSocket('ws://127.0.0.1:3001')

ws.on('open', () => {
  console.log('✅ Connected successfully!')

  // Test deposit
  ws.send(JSON.stringify({
    type: 'deposit',
    accountId: 'test-user',
    asset: 'USDT',
    amount: 1000
  }))

  setTimeout(() => {
    // Test withdraw
    ws.send(JSON.stringify({
      type: 'withdraw',
      accountId: 'test-user',
      asset: 'USDT',
      amount: 100
    }))

    setTimeout(() => {
      ws.close()
    }, 1000)
  }, 1000)
})

ws.on('message', (data) => {
  console.log('📥 Received:', data.toString())
})

ws.on('error', (err) => {
  console.error('❌ Error:', err.code)
})

ws.on('close', () => {
  console.log('🔌 Connection closed')
  process.exit(0)
})