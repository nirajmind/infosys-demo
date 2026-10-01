# ==============================================================================
# Stop Kong Data Plane (DP) for Infosys POC
# ==============================================================================

$CONTAINER_NAME = "infosys-dp-node-01"

$existing = docker ps -aq -f "name=$CONTAINER_NAME"
if ($existing) {
    Write-Host "Stopping and removing container $CONTAINER_NAME..." -ForegroundColor Yellow
    docker rm -f $CONTAINER_NAME | Out-Null
    Write-Host "✓ $CONTAINER_NAME removed." -ForegroundColor Green
} else {
    Write-Host "$CONTAINER_NAME is not currently running." -ForegroundColor Gray
}
