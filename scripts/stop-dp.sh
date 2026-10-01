#!/usr/bin/env bash
# ==============================================================================
# Stop Kong Data Plane (DP) for Infosys POC (Bash)
# ==============================================================================

set -euo pipefail

CONTAINER_NAME="infosys-dp-node-01"

if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "Stopping and removing container ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" > /dev/null 2>&1
    echo "[OK] ${CONTAINER_NAME} removed."
else
    echo "${CONTAINER_NAME} is not running."
fi
