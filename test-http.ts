import http from 'http'

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' })
  res.end('Hello World\n')
})

server.listen(3001, '127.0.0.1', () => {
  console.log('✅ HTTP server listening on http://127.0.0.1:3001')
})

server.on('error', (err: any) => {
  console.error('❌ HTTP server error:', err)
  process.exit(1)
})

// Keep alive
process.stdin.resume()