# ==============================================================================
# Start Kong Data Plane (DP) for Infosys POC
# Connects to Konnect Control Plane: infosys-poc-cp (0646a7d680.us.cp.konghq.com)
# ==============================================================================

$CONTAINER_NAME = "infosys-dp-node-01"
$IMAGE_NAME = "kong/kong-gateway:3.13"

# Resolve absolute certs directory path
$CERTS_DIR = (Resolve-Path "$PSScriptRoot\..\certs").Path

# Check if certs exist
if (!(Test-Path "$CERTS_DIR\tls.crt") -or !(Test-Path "$CERTS_DIR\tls.key")) {
    Write-Error "mTLS certificates missing in $CERTS_DIR! Please ensure tls.crt and tls.key are present."
    exit 1
}

# Stop existing container if running
$existing = docker ps -aq -f "name=$CONTAINER_NAME"
if ($existing) {
    Write-Host "Stopping and removing existing $CONTAINER_NAME..." -ForegroundColor Yellow
    docker rm -f $CONTAINER_NAME | Out-Null
}

Write-Host "Starting Kong Data Plane container: $CONTAINER_NAME..." -ForegroundColor Cyan
Write-Host "  Control Plane: 0646a7d680.us.cp.konghq.com:443" -ForegroundColor Gray
Write-Host "  HTTP Proxy:    http://localhost:8010" -ForegroundColor Gray
Write-Host "  HTTPS Proxy:   https://localhost:8453" -ForegroundColor Gray
Write-Host "  Status API:    http://localhost:8101/status" -ForegroundColor Gray

$certMount = "${CERTS_DIR}:/etc/kong/certs:ro"

$dockerArgs = @(
    "run", "-d",
    "--name", $CONTAINER_NAME,
    "-p", "8010:8000",
    "-p", "8453:8443",
    "-p", "8101:8100",
    "-v", $certMount,
    "-e", "KONG_ROLE=data_plane",
    "-e", "KONG_DATABASE=off",
    "-e", "KONG_KONNECT_MODE=on",
    "-e", "KONG_CLUSTER_MTLS=pki",
    "-e", "KONG_CLUSTER_CONTROL_PLANE=0646a7d680.us.cp.konghq.com:443",
    "-e", "KONG_CLUSTER_SERVER_NAME=0646a7d680.us.cp.konghq.com",
    "-e", "KONG_CLUSTER_TELEMETRY_ENDPOINT=0646a7d680.us.tp.konghq.com:443",
    "-e", "KONG_CLUSTER_TELEMETRY_SERVER_NAME=0646a7d680.us.tp.konghq.com",
    "-e", "KONG_CLUSTER_CERT=/etc/kong/certs/tls.crt",
    "-e", "KONG_CLUSTER_CERT_KEY=/etc/kong/certs/tls.key",
    "-e", "KONG_LUA_SSL_TRUSTED_CERTIFICATE=system",
    "-e", "KONG_STATUS_LISTEN=0.0.0.0:8100",
    "-e", "KONG_PROXY_LISTEN=0.0.0.0:8000, 0.0.0.0:8443 ssl",
    "-e", "KONG_NGINX_HTTP_LUA_SHARED_DICT=kong_rate_limiting_throttling 10m",
    "-e", "KONG_LOG_LEVEL=notice",
    $IMAGE_NAME
)

& docker @dockerArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "Waiting 5 seconds for DP initialization and CP sync..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    try {
        $status = Invoke-RestMethod -Uri "http://localhost:8101/status" -TimeoutSec 5
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "[OK] DP Status Report:" -ForegroundColor Green
        Write-Host "  Kong Version:       $($status.version)" -ForegroundColor Green
        Write-Host "  Configuration Hash: $($status.configuration_hash)" -ForegroundColor Green
        Write-Host "  CP Sync Time:       $([DateTimeOffset]::FromUnixTimeSeconds($status.sync_v1_last_time).LocalDateTime)" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
    } catch {
        Write-Warning "DP started but Status API not yet ready. Check 'docker logs $CONTAINER_NAME'."
    }
} else {
    Write-Error "Failed to launch $CONTAINER_NAME container."
}
