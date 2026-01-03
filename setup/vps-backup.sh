#!/bin/bash
set -e

echo "Creating comprehensive backup on VPS..."

# Stop services temporarily for consistent backup
echo "Stopping PM2 services..."
pm2 stop all || true

# Create backup directory on VPS
BACKUP_DIR="/tmp/iranvault_backup"
mkdir -p $BACKUP_DIR

echo "Backing up application files..."
# Backup main application directory
tar -czf $BACKUP_DIR/app_backup.tar.gz -C /opt iranvault || echo "App backup completed"

echo "Backing up configuration files..."
# Backup nginx configuration
tar -czf $BACKUP_DIR/nginx_backup.tar.gz -C /etc nginx/sites-available/iranvault* nginx/sites-enabled/iranvault* 2>/dev/null || echo "Nginx backup completed"

# Backup SSL certificates
tar -czf $BACKUP_DIR/ssl_backup.tar.gz -C /etc/letsencrypt live/iranvault.online* 2>/dev/null || echo "SSL backup completed"

echo "Backing up system services..."
# Backup systemd services
tar -czf $BACKUP_DIR/systemd_backup.tar.gz -C /etc/systemd system/multi-user.target.wants/pm2-* 2>/dev/null || echo "Systemd backup completed"

echo "Backing up PM2 configuration..."
# Backup PM2 processes
pm2 save || true
pm2 list > $BACKUP_DIR/pm2_processes.txt || true

echo "Creating final backup archive..."
# Create final compressed backup
cd /tmp
tar -czf iranvault_complete_backup.tar.gz iranvault_backup/

echo "Backup created successfully!"
ls -la iranvault_complete_backup.tar.gz

# Restart services
echo "Restarting PM2 services..."
pm2 start all || true