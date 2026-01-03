// Setup script for test balances
const { BalanceManager } = require('./engine/balances')

const balances = new BalanceManager()

// Deposit test funds
balances.deposit('maker-user', 'BTC', 1.0)  // 1 BTC
balances.deposit('taker-user', 'USDT', 100000)  // 100k USDT

console.log('💰 Deposited test funds:')
console.log('maker-user BTC:', balances.get('maker-user', 'BTC'))
console.log('taker-user USDT:', balances.get('taker-user', 'USDT'))