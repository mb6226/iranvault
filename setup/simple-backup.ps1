# Simple VPS Backup Script
# Uploads and runs backup script on VPS

param(
    [string]$VpsIp = "171.22.174.195",
    [string]$BackupDir = "C:\iranvault\backups"
)

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupName = "iranvault_backup_$Timestamp.tar.gz"
$BackupPath = "$BackupDir\$BackupName"

# Colors for output
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

Write-Status "Starting IranVault VPS backup..."
Write-Status "Timestamp: $Timestamp"

# Create backup directory if it doesn't exist
if (!(Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Status "Created backup directory: $BackupDir"
}

try {
    # Upload backup script to VPS
    Write-Status "Uploading backup script to VPS..."
    & scp -i C:\iranvault\setup\deployer_id_ed25519 C:\iranvault\setup\vps-backup.sh deployer@$VpsIp`:/tmp/vps-backup.sh

    # Run backup script on VPS
    Write-Status "Running backup on VPS..."
    & ssh -i C:\iranvault\setup\deployer_id_ed25519 deployer@$VpsIp "chmod +x /tmp/vps-backup.sh && /tmp/vps-backup.sh"

    # Download backup file
    Write-Status "Downloading backup file..."
    & scp -i C:\iranvault\setup\deployer_id_ed25519 deployer@$VpsIp`:/tmp/iranvault_complete_backup.tar.gz $BackupPath

    # Verify backup
    if (Test-Path $BackupPath) {
        $FileSize = (Get-Item $BackupPath).Length / 1MB
        Write-Status "Backup completed successfully!"
        Write-Status "Backup saved to: $BackupPath"
        Write-Status ("Backup file size: {0:N2} MB" -f $FileSize)
    } else {
        Write-Error "Backup file not found at expected location!"
        exit 1
    }

} catch {
    Write-Error "Backup failed: $($_.Exception.Message)"
    exit 1
}

Write-Status "IranVault VPS backup completed successfully!"