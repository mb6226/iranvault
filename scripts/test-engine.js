// Test script for DEX engine with vault events
const WebSocket = require('ws')

console.log('🔌 Attempting to connect to ws://localhost:3001')

const ws = new WebSocket('ws://localhost:3001')

ws.on('open', () => {
  console.log('🔌 Connected to DEX Engine')

  // Test deposit
  ws.send(JSON.stringify({
    type: 'deposit',
    accountId: 'test-user',
    asset: 'USDT',
    amount: 1000
  }))

  // Test withdraw
  setTimeout(() => {
    ws.send(JSON.stringify({
      type: 'withdraw',
      accountId: 'test-user',
      asset: 'USDT',
      amount: 100
    }))
  }, 1000)

  // Test order placement
  setTimeout(() => {
    ws.send(JSON.stringify({
      type: 'order',
      data: {
        side: 'buy',
        price: 50000,
        amount: 0.001,
        accountId: 'test-user'
      }
    }))
  }, 2000)
})

ws.on('message', (data) => {
  const msg = JSON.parse(data.toString())
  console.log('📥 Received:', msg)
})

ws.on('close', (code, reason) => {
  console.log('🔌 Disconnected - Code:', code, 'Reason:', reason.toString())
})

ws.on('error', (err) => {
  console.error('❌ Error:', err.message)
  console.error('❌ Error code:', err.code)
})