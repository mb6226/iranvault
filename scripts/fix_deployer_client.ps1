param(
  [string]$KeyPath = "C:\\iranvault\\setup\\deployer_id_ed25519",
  [string]$DestName = "id_deployer",
  [string]$TestHost = "171.22.174.195"
)

Write-Host "Client helper: preparing SSH private key and testing connection"

$destDir = Join-Path $env:USERPROFILE ".ssh"
if(-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }

$destPath = Join-Path $destDir $DestName

if(-not (Test-Path $KeyPath)) {
  Write-Error "Key file not found: $KeyPath"
  exit 2
}

Copy-Item -Path $KeyPath -Destination $destPath -Force

# Set strict ACLs: remove inheritance and grant current user read
icacls $destPath /inheritance:r | Out-Null
icacls $destPath /grant:r "$($env:USERNAME):(R)" | Out-Null
Unblock-File -Path $destPath

Write-Host "Key copied to $destPath and ACLs set for $($env:USERNAME)"

Write-Host "Testing connectivity to $TestHost..."
Test-NetConnection -ComputerName $TestHost -Port 22 | Format-List

Write-Host "Attempting SSH (verbose)..."
ssh -i $destPath -o IdentitiesOnly=yes -vvv deployer@$TestHost
