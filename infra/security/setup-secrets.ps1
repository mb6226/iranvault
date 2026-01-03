# IranVault Security Setup Script
# This script sets up all necessary secrets for production deployment

param(
    [string]$Namespace = "iranvault-prod",
    [switch]$DryRun
)

Write-Host "🔐 IranVault Security Setup Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Function to generate random base64 secret
function Generate-Secret {
    param([int]$Length = 32)
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return [Convert]::ToBase64String($bytes)
}

# Function to encode string to base64
function Encode-Base64 {
    param([string]$Text)
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Text))
}

# Create namespace if it doesn't exist
if (-not $DryRun) {
    Write-Host "📁 Creating namespace: $Namespace" -ForegroundColor Yellow
    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
}

# JWT Secrets
Write-Host "🔑 Setting up JWT secrets..." -ForegroundColor Green
$jwtSecret = Generate-Secret
$jwtRefreshSecret = Generate-Secret

$jwtSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secret
  namespace: $Namespace
type: Opaque
data:
  JWT_SECRET: $jwtSecret
  JWT_REFRESH_SECRET: $jwtRefreshSecret
"@

if ($DryRun) {
    Write-Host "DRY RUN: Would create JWT secret" -ForegroundColor Magenta
    Write-Host $jwtSecretYaml -ForegroundColor Gray
} else {
    $jwtSecretYaml | kubectl apply -f -
    Write-Host "✅ JWT secrets created" -ForegroundColor Green
}

# Database Secrets
Write-Host "🗄️ Setting up database secrets..." -ForegroundColor Green
$dbUser = "iranvault"
$dbPassword = Generate-Secret -Length 24
$dbName = "iranvault_prod"

$dbSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: $Namespace
type: Opaque
data:
  POSTGRES_USER: $(Encode-Base64 $dbUser)
  POSTGRES_PASSWORD: $dbPassword
  POSTGRES_DB: $(Encode-Base64 $dbName)
"@

if ($DryRun) {
    Write-Host "DRY RUN: Would create database secret" -ForegroundColor Magenta
    Write-Host $dbSecretYaml -ForegroundColor Gray
} else {
    $dbSecretYaml | kubectl apply -f -
    Write-Host "✅ Database secrets created" -ForegroundColor Green
}

# Redis Secrets
Write-Host "🔴 Setting up Redis secrets..." -ForegroundColor Green
$redisPassword = Generate-Secret -Length 24

$redisSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
  namespace: $Namespace
type: Opaque
data:
  REDIS_PASSWORD: $redisPassword
"@

if ($DryRun) {
    Write-Host "DRY RUN: Would create Redis secret" -ForegroundColor Magenta
    Write-Host $redisSecretYaml -ForegroundColor Gray
} else {
    $redisSecretYaml | kubectl apply -f -
    Write-Host "✅ Redis secrets created" -ForegroundColor Green
}

# NATS Secrets
Write-Host "📡 Setting up NATS secrets..." -ForegroundColor Green
$natsUser = "iranvault"
$natsPassword = Generate-Secret -Length 24

$natsSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: nats-secret
  namespace: $Namespace
type: Opaque
data:
  NATS_USER: $(Encode-Base64 $natsUser)
  NATS_PASSWORD: $natsPassword
"@

if ($DryRun) {
    Write-Host "DRY RUN: Would create NATS secret" -ForegroundColor Magenta
    Write-Host $natsSecretYaml -ForegroundColor Gray
} else {
    $natsSecretYaml | kubectl apply -f -
    Write-Host "✅ NATS secrets created" -ForegroundColor Green
}

# External API Secrets (placeholders - need to be filled manually)
Write-Host "🌐 Setting up external API secrets (placeholders)..." -ForegroundColor Yellow
$externalApiSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: external-apis-secret
  namespace: $Namespace
type: Opaque
data:
  BINANCE_API_KEY: <FILL_MANUALLY_BASE64_ENCODED>
  BINANCE_API_SECRET: <FILL_MANUALLY_BASE64_ENCODED>
  COINGECKO_API_KEY: <FILL_MANUALLY_BASE64_ENCODED>
"@

if ($DryRun) {
    Write-Host "DRY RUN: Would create external API secret template" -ForegroundColor Magenta
    Write-Host $externalApiSecretYaml -ForegroundColor Gray
} else {
    # Create with placeholder values - user needs to update manually
    $externalApiSecretYaml | kubectl apply -f -
    Write-Host "⚠️ External API secrets created with placeholders - UPDATE MANUALLY" -ForegroundColor Yellow
}

# Email Service Secrets (placeholders)
Write-Host "📧 Setting up email service secrets (placeholders)..." -ForegroundColor Yellow
$emailSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: email-secret
  namespace: $Namespace
type: Opaque
data:
  SMTP_HOST: <FILL_MANUALLY_BASE64_ENCODED>
  SMTP_PORT: <FILL_MANUALLY_BASE64_ENCODED>
  SMTP_USER: <FILL_MANUALLY_BASE64_ENCODED>
  SMTP_PASSWORD: <FILL_MANUALLY_BASE64_ENCODED>
  FROM_EMAIL: <FILL_MANUALLY_BASE64_ENCODED>
"@

if ($DryRun) {
    Write-Host "DRY RUN: Would create email secret template" -ForegroundColor Magenta
    Write-Host $emailSecretYaml -ForegroundColor Gray
} else {
    $emailSecretYaml | kubectl apply -f -
    Write-Host "⚠️ Email secrets created with placeholders - UPDATE MANUALLY" -ForegroundColor Yellow
}

# Monitoring Secrets
Write-Host "📊 Setting up monitoring secrets..." -ForegroundColor Green
$grafanaPassword = Generate-Secret -Length 16
$prometheusUser = "admin"
$prometheusPassword = Generate-Secret -Length 16

$monitoringSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: monitoring-secret
  namespace: $Namespace
type: Opaque
data:
  GRAFANA_ADMIN_PASSWORD: $grafanaPassword
  PROMETHEUS_USERNAME: $(Encode-Base64 $prometheusUser)
  PROMETHEUS_PASSWORD: $prometheusPassword
"@

if ($DryRun) {
    Write-Host "DRY RUN: Would create monitoring secret" -ForegroundColor Magenta
    Write-Host $monitoringSecretYaml -ForegroundColor Gray
} else {
    $monitoringSecretYaml | kubectl apply -f -
    Write-Host "✅ Monitoring secrets created" -ForegroundColor Green
}

# Generate self-signed certificates for mTLS (for development/testing)
Write-Host "🔒 Generating self-signed certificates for mTLS..." -ForegroundColor Green

$certDir = "$PSScriptRoot\certs"
if (-not (Test-Path $certDir)) {
    New-Item -ItemType Directory -Path $certDir -Force | Out-Null
}

# Generate CA
$caKeyPath = "$certDir\ca.key"
$caCertPath = "$certDir\ca.crt"

if (-not (Test-Path $caKeyPath)) {
    Write-Host "Generating CA certificate..." -ForegroundColor Yellow
    openssl genrsa -out $caKeyPath 2048 2>$null
    openssl req -x509 -new -nodes -key $caKeyPath -sha256 -days 3650 -out $caCertPath -subj "/C=IR/ST=Tehran/L=Tehran/O=IranVault/OU=Security/CN=IranVault CA" 2>$null
}

# Function to generate service certificate
function Generate-ServiceCert {
    param([string]$ServiceName)

    $keyPath = "$certDir\$ServiceName.key"
    $csrPath = "$certDir\$ServiceName.csr"
    $certPath = "$certDir\$ServiceName.crt"

    if (-not (Test-Path $keyPath)) {
        Write-Host "Generating certificate for $ServiceName..." -ForegroundColor Yellow
        openssl genrsa -out $keyPath 2048 2>$null
        openssl req -new -key $keyPath -out $csrPath -subj "/C=IR/ST=Tehran/L=Tehran/O=IranVault/OU=$ServiceName/CN=$ServiceName.iranvault-prod.svc.cluster.local" 2>$null
        openssl x509 -req -in $csrPath -CA $caCertPath -CAkey $caKeyPath -CAcreateserial -out $certPath -days 365 -sha256 2>$null
    }

    return @{
        Key = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keyPath))
        Cert = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($certPath))
    }
}

$services = @("api-gateway", "auth-service", "order-service", "matching-engine")
foreach ($service in $services) {
    $cert = Generate-ServiceCert $service

    $tlsSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: $service-tls
  namespace: $Namespace
type: kubernetes.io/tls
data:
  tls.crt: $($cert.Cert)
  tls.key: $($cert.Key)
"@

    if ($DryRun) {
        Write-Host "DRY RUN: Would create TLS secret for $service" -ForegroundColor Magenta
    } else {
        $tlsSecretYaml | kubectl apply -f -
        Write-Host "✅ TLS secret created for $service" -ForegroundColor Green
    }
}

# Create CA secret
$caCert = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($caCertPath))
$caKey = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($caKeyPath))

$caSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: iranvault-ca
  namespace: $Namespace
type: Opaque
data:
  ca.crt: $caCert
  ca.key: $caKey
"@

if ($DryRun) {
    Write-Host "DRY RUN: Would create CA secret" -ForegroundColor Magenta
} else {
    $caSecretYaml | kubectl apply -f -
    Write-Host "✅ CA secret created" -ForegroundColor Green
}

# Summary
Write-Host "`n🎉 Security setup completed!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "This was a DRY RUN - no changes were applied" -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply changes" -ForegroundColor Yellow
} else {
    Write-Host "Generated secrets:" -ForegroundColor Green
    Write-Host "  ✅ JWT secrets" -ForegroundColor Green
    Write-Host "  ✅ Database secrets" -ForegroundColor Green
    Write-Host "  ✅ Redis secrets" -ForegroundColor Green
    Write-Host "  ✅ NATS secrets" -ForegroundColor Green
    Write-Host "  ⚠️ External API secrets (need manual configuration)" -ForegroundColor Yellow
    Write-Host "  ⚠️ Email secrets (need manual configuration)" -ForegroundColor Yellow
    Write-Host "  ✅ Monitoring secrets" -ForegroundColor Green
    Write-Host "  ✅ mTLS certificates" -ForegroundColor Green

    Write-Host "`n🔐 Security Recommendations:" -ForegroundColor Cyan
    Write-Host "  1. Update external API keys manually" -ForegroundColor White
    Write-Host "  2. Configure email service credentials" -ForegroundColor White
    Write-Host "  3. Set up proper TLS certificates for production" -ForegroundColor White
    Write-Host "  4. Configure cloud provider secrets if needed" -ForegroundColor White
    Write-Host "  5. Enable secret rotation policies" -ForegroundColor White

    Write-Host "`n📁 Certificate files generated in: $certDir" -ForegroundColor White
    Write-Host "   (Keep these secure and backup appropriately)" -ForegroundColor White
}