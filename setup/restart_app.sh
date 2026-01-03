#!/bin/bash
# IranVault UI Restart Script
# This script cleanly restarts the application

echo "🛑 Stopping all processes..."
pkill -f 'next\|node' || true
npx pm2 kill || true

echo "🔄 Rebuilding application..."
cd /opt/iranvault/iranvault-ui
npm run build

echo "🚀 Starting application..."
npx pm2 start npm --name iranvault-ui -- run start

echo "✅ Done! Check https://iranvault.online"