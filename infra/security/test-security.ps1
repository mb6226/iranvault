# IranVault Security Testing Script
# Tests security controls and validates hardening

param(
    [string]$ApiUrl = "https://api.iranvault.com",
    [switch]$SkipDestructiveTests,
    [int]$TestDuration = 30
)

Write-Host "🧪 IranVault Security Testing Suite" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

# Function to make HTTP request and check response
function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$ExpectedStatus = "200",
        [string]$TestName
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $Headers -SkipHttpErrorCheck
        $status = $response.StatusCode.ToString()

        if ($status -eq $ExpectedStatus) {
            Write-Host "  ✅ $TestName - Status: $status" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ❌ $TestName - Expected: $ExpectedStatus, Got: $status" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  ❌ $TestName - Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test rate limiting
function Test-RateLimiting {
    param([string]$Url, [string]$TestName, [int]$RequestCount = 10)

    Write-Host "Testing $TestName rate limiting..." -ForegroundColor Yellow

    $rateLimited = $false
    for ($i = 1; $i -le $RequestCount; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -SkipHttpErrorCheck
            if ($response.StatusCode -eq 429) {
                $rateLimited = $true
                Write-Host "  ✅ Rate limit triggered on request $i" -ForegroundColor Green
                break
            }
        } catch {
            # Continue testing
        }
        Start-Sleep -Milliseconds 100
    }

    if (-not $rateLimited) {
        Write-Host "  ⚠️ Rate limit not triggered after $RequestCount requests" -ForegroundColor Yellow
    }
}

# Function to test WAF
function Test-WAF {
    Write-Host "Testing WAF protection..." -ForegroundColor Yellow

    $wafTests = @(
        @{ Url = "$ApiUrl/api/v1/orders?id=1' OR '1'='1"; Name = "SQL Injection"; Expected = "403" }
        @{ Url = "$ApiUrl/api/v1/search?q=<script>alert('xss')</script>"; Name = "XSS Attack"; Expected = "403" }
        @{ Url = "$ApiUrl/api/v1/../../../etc/passwd"; Name = "Path Traversal"; Expected = "403" }
        @{ Url = "$ApiUrl/api/v1/orders"; Headers = @{ "User-Agent" = "sqlmap" }; Name = "Bad Bot Detection"; Expected = "403" }
    )

    foreach ($test in $wafTests) {
        Test-Endpoint -Url $test.Url -Headers $test.Headers -ExpectedStatus $test.Expected -TestName "WAF: $($test.Name)"
    }
}

# Function to test security headers
function Test-SecurityHeaders {
    Write-Host "Testing security headers..." -ForegroundColor Yellow

    try {
        $response = Invoke-WebRequest -Uri "$ApiUrl/api/v1/health" -SkipHttpErrorCheck

        $requiredHeaders = @(
            "X-Frame-Options",
            "X-Content-Type-Options",
            "X-XSS-Protection",
            "Strict-Transport-Security"
        )

        foreach ($header in $requiredHeaders) {
            if ($response.Headers.ContainsKey($header)) {
                Write-Host "  ✅ Security header present: $header" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Missing security header: $header" -ForegroundColor Red
            }
        }

        # Check HSTS max-age
        if ($response.Headers.ContainsKey("Strict-Transport-Security")) {
            $hsts = $response.Headers["Strict-Transport-Security"]
            if ($hsts -match "max-age=(\d+)") {
                $maxAge = [int]$matches[1]
                if ($maxAge -ge 31536000) { # 1 year
                    Write-Host "  ✅ HSTS max-age sufficient: $maxAge seconds" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠️ HSTS max-age too short: $maxAge seconds" -ForegroundColor Yellow
                }
            }
        }

    } catch {
        Write-Host "  ❌ Could not test security headers: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to test SSL/TLS
function Test-SSL {
    Write-Host "Testing SSL/TLS configuration..." -ForegroundColor Yellow

    try {
        $request = [System.Net.WebRequest]::Create($ApiUrl)
        $response = $request.GetResponse()
        $cert = $response.ServicePoint.Certificate

        if ($cert) {
            Write-Host "  ✅ SSL certificate present" -ForegroundColor Green

            # Check certificate validity
            $now = Get-Date
            if ($cert.NotBefore -lt $now -and $cert.NotAfter -gt $now) {
                Write-Host "  ✅ SSL certificate is valid" -ForegroundColor Green
            } else {
                Write-Host "  ❌ SSL certificate is expired or not yet valid" -ForegroundColor Red
            }

            # Check issuer
            Write-Host "  ℹ️ Certificate issuer: $($cert.Issuer)" -ForegroundColor White
            Write-Host "  ℹ️ Certificate subject: $($cert.Subject)" -ForegroundColor White

        } else {
            Write-Host "  ❌ No SSL certificate found" -ForegroundColor Red
        }

        $response.Close()

    } catch {
        Write-Host "  ❌ SSL test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to test DDoS resilience (basic)
function Test-DDoSResilience {
    if ($SkipDestructiveTests) {
        Write-Host "Skipping DDoS resilience test (destructive tests disabled)" -ForegroundColor Yellow
        return
    }

    Write-Host "Testing DDoS resilience (basic load test)..." -ForegroundColor Yellow

    $startTime = Get-Date
    $requests = 0
    $errors = 0

    while ((Get-Date) - $startTime).TotalSeconds -lt $TestDuration) {
        try {
            $response = Invoke-WebRequest -Uri "$ApiUrl/api/v1/health" -TimeoutSec 5 -SkipHttpErrorCheck
            $requests++

            if ($response.StatusCode -ne 200) {
                $errors++
            }
        } catch {
            $errors++
        }
    }

    $successRate = [math]::Round((($requests - $errors) / $requests) * 100, 2)

    Write-Host "  📊 Load test results:" -ForegroundColor White
    Write-Host "    Total requests: $requests" -ForegroundColor White
    Write-Host "    Errors: $errors" -ForegroundColor White
    Write-Host "    Success rate: $successRate%" -ForegroundColor White

    if ($successRate -gt 95) {
        Write-Host "  ✅ Good resilience under load" -ForegroundColor Green
    } elseif ($successRate -gt 80) {
        Write-Host "  ⚠️ Moderate resilience under load" -ForegroundColor Yellow
    } else {
        Write-Host "  ❌ Poor resilience under load" -ForegroundColor Red
    }
}

# Main test execution
Write-Host "Starting security tests against: $ApiUrl" -ForegroundColor Cyan
Write-Host "Test duration: $TestDuration seconds" -ForegroundColor White
Write-Host ""

# Basic connectivity test
Write-Host "🔗 Testing basic connectivity..." -ForegroundColor Yellow
Test-Endpoint -Url "$ApiUrl/api/v1/health" -TestName "Health Check"

# Security headers test
Test-SecurityHeaders

# SSL/TLS test
Test-SSL

# WAF tests
Test-WAF

# Rate limiting tests
Test-RateLimiting -Url "$ApiUrl/api/v1/auth/login" -TestName "Authentication" -RequestCount 20
Test-RateLimiting -Url "$ApiUrl/api/v1/orders" -TestName "Trading" -RequestCount 60
Test-RateLimiting -Url "$ApiUrl/api/v1/market/ticker" -TestName "Market Data" -RequestCount 600

# DDoS resilience test
Test-DDoSResilience

# Summary
Write-Host ""
Write-Host "🎯 Security Testing Complete!" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

Write-Host "📋 Test Summary:" -ForegroundColor White
Write-Host "  • Basic connectivity and health checks" -ForegroundColor White
Write-Host "  • Security headers validation" -ForegroundColor White
Write-Host "  • SSL/TLS certificate validation" -ForegroundColor White
Write-Host "  • WAF protection against common attacks" -ForegroundColor White
Write-Host "  • Rate limiting effectiveness" -ForegroundColor White
if (-not $SkipDestructiveTests) {
    Write-Host "  • DDoS resilience under load" -ForegroundColor White
}

Write-Host ""
Write-Host "🔍 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review any failed tests above" -ForegroundColor White
Write-Host "  2. Check monitoring dashboards for alerts" -ForegroundColor White
Write-Host "  3. Review security logs for blocked requests" -ForegroundColor White
Write-Host "  4. Perform penetration testing with professional tools" -ForegroundColor White
Write-Host "  5. Schedule regular security audits" -ForegroundColor White

Write-Host ""
Write-Host "📞 For security issues, contact: security@iranvault.com" -ForegroundColor Yellow