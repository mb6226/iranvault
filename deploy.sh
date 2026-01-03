#!/bin/bash
# IranVault Deployment Script
# This script deploys the complete DEX system on the VPS

set -e  # Exit on any error

echo "🚀 Starting IranVault deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -d "/opt/iranvault" ]; then
    print_error "IranVault directory not found at /opt/iranvault"
    exit 1
fi

cd /opt/iranvault

# Install dependencies for engine
print_status "Installing engine dependencies..."
cd engine
npm install --production
npm install typescript --save-dev  # Install TypeScript for building
cd ..

# Install dependencies for UI
print_status "Installing UI dependencies..."
cd iranvault-ui
npm install --production
cd ..

# Build engine (in case not built locally)
print_status "Building engine..."
cd engine
npm run build
cd ..

# Build UI (in case not built locally)
print_status "Building UI..."
cd iranvault-ui
npm run build
cd ..

# Stop existing processes
print_status "Stopping existing processes..."
pkill -f 'next\|node.*ws\|node.*server' || true
npx pm2 kill || true
npx pm2 delete all || true

# Start the DEX engine (WebSocket server)
print_status "Starting DEX engine..."
cd engine
npx pm2 start npm --name iranvault-engine -- run start
cd ..

# Start the UI
print_status "Starting UI..."
cd iranvault-ui
npx pm2 start npm --name iranvault-ui -- run start
cd ..

# Save PM2 configuration
print_status "Saving PM2 configuration..."
npx pm2 save

# Setup PM2 to start on boot
print_status "Setting up PM2 startup..."
npx pm2 startup
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u deployer --hp /home/deployer || true

# Check if services are running
print_status "Checking service status..."
sleep 5
npx pm2 status

# Test the services
print_status "Testing services..."
curl -f http://localhost:3000 > /dev/null 2>&1 && print_status "UI is responding" || print_warning "UI not responding yet"

# Check if WebSocket port is listening
if lsof -i :3001 > /dev/null 2>&1; then
    print_status "WebSocket server is listening on port 3001"
else
    print_warning "WebSocket server not listening on port 3001 yet"
fi

print_status "🎉 Deployment completed!"
print_status "🌐 UI: https://iranvault.online"
print_status "🔌 Engine: ws://iranvault.online:3001"
print_status "📊 Check status: pm2 status"
print_status "📝 View logs: pm2 logs"