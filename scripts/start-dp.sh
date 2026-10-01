#!/usr/bin/env bash
# ==============================================================================
# Start Kong Data Plane (DP) for Infosys POC (Bash)
# Connects to Konnect Control Plane: infosys-poc-cp (0646a7d680.us.cp.konghq.com)
# ==============================================================================

set -euo pipefail

CONTAINER_NAME="infosys-dp-node-01"
IMAGE_NAME="kong/kong-gateway:3.13"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../certs"

if [ ! -f "${CERTS_DIR}/tls.crt" ] || [ ! -f "${CERTS_DIR}/tls.key" ]; then
    echo "ERROR: mTLS certificates missing in ${CERTS_DIR}!"
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "Stopping existing ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" > /dev/null 2>&1 || true
fi

echo "Starting Kong Data Plane container: ${CONTAINER_NAME}..."
echo "  Control Plane: 0646a7d680.us.cp.konghq.com:443"
echo "  HTTP Proxy:    http://localhost:8010"
echo "  HTTPS Proxy:   https://localhost:8453"
echo "  Status API:    http://localhost:8101/status"

docker run -d \
    --name "${CONTAINER_NAME}" \
    -p 8010:8000 \
    -p 8453:8443 \
    -p 8101:8100 \
    -v "${CERTS_DIR}:/etc/kong/certs:ro" \
    -e "KONG_ROLE=data_plane" \
    -e "KONG_DATABASE=off" \
    -e "KONG_KONNECT_MODE=on" \
    -e "KONG_CLUSTER_MTLS=pki" \
    -e "KONG_CLUSTER_CONTROL_PLANE=0646a7d680.us.cp.konghq.com:443" \
    -e "KONG_CLUSTER_SERVER_NAME=0646a7d680.us.cp.konghq.com" \
    -e "KONG_CLUSTER_TELEMETRY_ENDPOINT=0646a7d680.us.tp.konghq.com:443" \
    -e "KONG_CLUSTER_TELEMETRY_SERVER_NAME=0646a7d680.us.tp.konghq.com" \
    -e "KONG_CLUSTER_CERT=/etc/kong/certs/tls.crt" \
    -e "KONG_CLUSTER_CERT_KEY=/etc/kong/certs/tls.key" \
    -e "KONG_LUA_SSL_TRUSTED_CERTIFICATE=system" \
    -e "KONG_STATUS_LISTEN=0.0.0.0:8100" \
    -e "KONG_PROXY_LISTEN=0.0.0.0:8000, 0.0.0.0:8443 ssl" \
    -e "KONG_NGINX_HTTP_LUA_SHARED_DICT=kong_rate_limiting_throttling 10m" \
    -e "KONG_LOG_LEVEL=notice" \
    "${IMAGE_NAME}"

echo "Waiting 5 seconds for DP initialization..."
sleep 5

curl -s "http://localhost:8101/status" | grep -q "configuration_hash" && echo "[OK] DP Status is ONLINE and synced with Konnect!" || echo "[WARNING] DP still initializing..."
