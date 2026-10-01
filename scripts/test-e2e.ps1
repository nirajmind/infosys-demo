# ==============================================================================
# End-to-End Automated Test Script for Kong Konnect Data Plane
# Validates DP Status, Route Matching, Host Isolation, Protocol Enforcement & Policies
# ==============================================================================

param(
    [string]$DpHost = "127.0.0.1",
    [int]$HttpPort = 8010,
    [int]$HttpsPort = 8453,
    [int]$StatusPort = 8101,
    [string]$TargetHostHeader = "itgatewaytst.infosysapps.com"
)

$ErrorActionPreference = "Continue"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Infosys Kong Konnect APIOps - Automated E2E Verification Suite" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Target Data Plane:  $DpHost"
Write-Host "HTTP Proxy Port:    $HttpPort"
Write-Host "HTTPS Proxy Port:   $HttpsPort"
Write-Host "Status API Port:    $StatusPort"
Write-Host "Host Header:        $TargetHostHeader"
Write-Host "-----------------------------------------------------------------"

$totalTests = 0
$passedTests = 0
$failedTests = 0

function Assert-Test {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Details
    )
    $script:totalTests++
    if ($Condition) {
        $script:passedTests++
        Write-Host " [PASS] $Name" -ForegroundColor Green
        if ($Details) { Write-Host "        $Details" -ForegroundColor Gray }
    } else {
        $script:failedTests++
        Write-Host " [FAIL] $Name" -ForegroundColor Red
        if ($Details) { Write-Host "        $Details" -ForegroundColor Yellow }
    }
}

# ------------------------------------------------------------------------------
# Test 1: Data Plane Status & Konnect CP Synchronization
# ------------------------------------------------------------------------------
Write-Host "`n--> [1/5] Checking Data Plane Health & Konnect CP Synchronization..." -ForegroundColor White
try {
    $statusJson = curl.exe -s --connect-timeout 5 "http://${DpHost}:${StatusPort}/status" | Out-String
    $statusObj = $statusJson | ConvertFrom-Json
    
    $hasValidHash = ($statusObj.configuration_hash -and $statusObj.configuration_hash -ne "00000000000000000000000000000000")
    $hasSyncPass = ($statusObj.sync_v1_last_time.pass -ne $null -and $statusObj.sync_v1_last_time.pass -ne "")
    
    Assert-Test -Name "DP is alive and reachable via Status API" -Condition ($statusObj -ne $null) -Details "Version: $($statusObj.version)"
    Assert-Test -Name "DP configuration is synchronized from Konnect CP" -Condition $hasValidHash -Details "Config Hash: $($statusObj.configuration_hash)"
    Assert-Test -Name "DP CP sync timestamp is verified" -Condition $hasSyncPass -Details "Sync: $($statusObj.sync_v1_last_time.pass)"
} catch {
    Assert-Test -Name "DP Status API connection" -Condition $false -Details $_.Exception.Message
}

# ------------------------------------------------------------------------------
# Test 2: Protocol Enforcement (HTTP -> HTTPS Guardrail)
# ------------------------------------------------------------------------------
Write-Host "`n--> [2/5] Testing HTTP -> HTTPS Security Enforcement..." -ForegroundColor White
try {
    $httpResp = curl.exe -s -i --connect-timeout 5 "http://${DpHost}:${HttpPort}/infydigital/CCPServices/health" -H "Host: $TargetHostHeader"
    $httpHeaders = $httpResp -join "`n"
    $is426 = ($httpHeaders -match "HTTP/1\.[01] 426" -or $httpHeaders -match "Please use HTTPS")
    
    Assert-Test -Name "HTTP requests are rejected with HTTPS upgrade requirement (426)" -Condition $is426 -Details "Kong enforced protocols: [https] policy rule."
} catch {
    Assert-Test -Name "HTTP security check" -Condition $false -Details $_.Exception.Message
}

# ------------------------------------------------------------------------------
# Test 3: Host Isolation & Negative Route Matching
# ------------------------------------------------------------------------------
Write-Host "`n--> [3/5] Testing Host Isolation (Negative Security Test)..." -ForegroundColor White
try {
    $badHostResp = curl.exe -s -i -k --ssl-no-revoke --connect-timeout 5 "https://${DpHost}:${HttpsPort}/infydigital/CCPServices/health" -H "Host: unauthorized-domain.com"
    $badHeaders = $badHostResp -join "`n"
    $is404 = ($badHeaders -match "HTTP/1\.[01] 404" -or $badHeaders -match "no Route matched")
    
    Assert-Test -Name "Requests with unauthorized Host header are rejected (404)" -Condition $is404 -Details "Host isolation prevents route shadowing and unauthorized access."
} catch {
    Assert-Test -Name "Host isolation check" -Condition $false -Details $_.Exception.Message
}

# ------------------------------------------------------------------------------
# Test 4: HTTPS Routing & Kong Gateway Processing
# ------------------------------------------------------------------------------
Write-Host "`n--> [4/5] Testing HTTPS Route Matching for Domain 'infydigital'..." -ForegroundColor White
try {
    $httpsResp = curl.exe -s -i -k --ssl-no-revoke --connect-timeout 5 --max-time 15 "https://${DpHost}:${HttpsPort}/infydigital/CCPServices/health" -H "Host: $TargetHostHeader"
    $httpsHeaders = $httpsResp -join "`n"
    
    $isProcessedByKong = ($httpsHeaders -match "Server: kong" -or $httpsHeaders -match "X-Kong-Response-Latency")
    $hasKongRequestId = ($httpsHeaders -match "X-Kong-Request-Id")
    
    Assert-Test -Name "HTTPS request is decrypted and processed by Kong Gateway" -Condition $isProcessedByKong -Details "Server header confirmed: Kong Enterprise Gateway"
    Assert-Test -Name "Kong assigned an enterprise trace Request-ID" -Condition $hasKongRequestId -Details ($httpsHeaders -split "`n" | Where-Object { $_ -match "X-Kong-Request-Id" })
} catch {
    Assert-Test -Name "HTTPS route matching" -Condition $false -Details $_.Exception.Message
}

# ------------------------------------------------------------------------------
# Test 5: Rate Limiting Policy & Header Verification
# ------------------------------------------------------------------------------
Write-Host "`n--> [5/5] Testing Rate Limiting & Enterprise Policy Enforcement..." -ForegroundColor White
try {
    $rlResp = curl.exe -s -i -k --ssl-no-revoke --connect-timeout 5 --max-time 15 "https://${DpHost}:${HttpsPort}/infydigital/CCPServices/health" -H "Host: $TargetHostHeader"
    $rlHeaders = $rlResp -join "`n"
    
    $hasRateLimitHeader = ($rlHeaders -match "RateLimit-Limit" -or $rlHeaders -match "X-RateLimit-Limit")
    $remainingMatch = [regex]::Match($rlHeaders, "RateLimit-Remaining: (\d+)")
    $remaining = if ($remainingMatch.Success) { $remainingMatch.Groups[1].Value } else { "N/A" }
    
    Assert-Test -Name "Rate Limiting Advanced headers are present in response" -Condition $hasRateLimitHeader -Details "Current Remaining Quota: $remaining"
} catch {
    Assert-Test -Name "Rate limiting check" -Condition $false -Details $_.Exception.Message
}

# ------------------------------------------------------------------------------
# Summary Report
# ------------------------------------------------------------------------------
Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "                     E2E Test Execution Summary" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Total Tests Executed: $totalTests"
Write-Host "Passed:               $passedTests" -ForegroundColor Green
Write-Host "Failed:               $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })
Write-Host "=================================================================" -ForegroundColor Cyan

if ($failedTests -eq 0) {
    Write-Host "[SUCCESS] All E2E validation tests passed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILURE] $failedTests test(s) failed." -ForegroundColor Red
    exit 1
}
