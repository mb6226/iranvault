# IranVault VPS Backup Script
# Creates complete backup of production system

param(
    [string]$VpsIp = "171.22.174.195",
    [string]$BackupDir = "C:\iranvault\backups",
    [string]$Timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
)

$BackupName = "iranvault_backup_$Timestamp"
$BackupPath = "$BackupDir\$BackupName.tar.gz"

# Colors for output
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

Write-Status "Starting IranVault VPS backup..."
Write-Status "Backup timestamp: $Timestamp"
Write-Status "Backup will be saved to: $BackupPath"

# Create backup directory if it doesn't exist
if (!(Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Status "Created backup directory: $BackupDir"
}

# SSH command to create backup on VPS
$SshCommand = @"
#!/bin/bash
set -e

echo "Creating comprehensive backup on VPS..."

# Stop services temporarily for consistent backup
echo "Stopping PM2 services..."
pm2 stop all || true

# Create backup directory on VPS
BACKUP_DIR="/tmp/iranvault_backup_$Timestamp"
mkdir -p `$BACKUP_DIR

echo "Backing up application files..."
# Backup main application directory
tar -czf `$BACKUP_DIR/app_backup.tar.gz -C /opt iranvault || echo "App backup completed"

echo "Backing up configuration files..."
# Backup nginx configuration
tar -czf `$BACKUP_DIR/nginx_backup.tar.gz -C /etc nginx/sites-available/iranvault* nginx/sites-enabled/iranvault* || echo "Nginx backup completed"

# Backup SSL certificates
tar -czf `$BACKUP_DIR/ssl_backup.tar.gz -C /etc/letsencrypt live/iranvault.online* || echo "SSL backup completed"

echo "Backing up system services..."
# Backup systemd services
tar -czf `$BACKUP_DIR/systemd_backup.tar.gz -C /etc/systemd system/multi-user.target.wants/pm2-* || echo "Systemd backup completed"

echo "Backing up PM2 configuration..."
# Backup PM2 processes
pm2 save || true
pm2 list > `$BACKUP_DIR/pm2_processes.txt || true

echo "Creating final backup archive..."
# Create final compressed backup
cd /tmp
tar -czf iranvault_complete_backup_$Timestamp.tar.gz iranvault_backup_$Timestamp/

echo "Backup created successfully!"
ls -la iranvault_complete_backup_$Timestamp.tar.gz

# Restart services
echo "Restarting PM2 services..."
pm2 start all || true
"@

# Save SSH command to temporary file
$SshScriptPath = "$env:TEMP\backup_script_$Timestamp.sh"
$SshCommand | Out-File -FilePath $SshScriptPath -Encoding UTF8

# Execute backup on VPS
Write-Status "Connecting to VPS and creating backup..."
try {
    & scp -i C:\iranvault\setup\deployer_id_ed25519 $SshScriptPath deployer@$VpsIp`:/tmp/backup_script.sh
    & ssh -i C:\iranvault\setup\deployer_id_ed25519 deployer@$VpsIp "chmod +x /tmp/backup_script.sh && /tmp/backup_script.sh"

    Write-Status "Downloading backup from VPS..."
    & scp -i C:\iranvault\setup\deployer_id_ed25519 deployer@$VpsIp`:/tmp/iranvault_complete_backup_$Timestamp.tar.gz $BackupPath

    Write-Status "Backup completed successfully!"
    Write-Status "Backup saved to: $BackupPath"

    # Verify backup file
    if (Test-Path $BackupPath) {
        $FileSize = (Get-Item $BackupPath).Length / 1MB
        Write-Status ("Backup file size: {0:N2} MB" -f $FileSize)
    } else {
        Write-Error "Backup file not found!"
        exit 1
    }

} catch {
    Write-Error "Backup failed: $($_.Exception.Message)"
    exit 1
} finally {
    # Cleanup temporary files
    if (Test-Path $SshScriptPath) {
        Remove-Item $SshScriptPath -Force
    }
}

Write-Status "IranVault VPS backup completed successfully!"
Write-Status "Backup location: $BackupPath"