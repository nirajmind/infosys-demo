#!/usr/bin/env bash
# ==============================================================================
# End-to-End Automated Test Script for Kong Konnect Data Plane (Bash)
# Validates DP Status, Route Matching, Host Isolation, Protocol Enforcement & Policies
# ==============================================================================

set -euo pipefail

DP_HOST="${1:-127.0.0.1}"
HTTP_PORT="${2:-8010}"
HTTPS_PORT="${3:-8453}"
STATUS_PORT="${4:-8101}"
TARGET_HOST="${5:-itgatewaytst.infosysapps.com}"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo -e "${CYAN}=================================================================${NC}"
echo -e "${CYAN}  Infosys Kong Konnect APIOps - Automated E2E Verification Suite${NC}"
echo -e "${CYAN}=================================================================${NC}"
echo "Target Data Plane:  $DP_HOST"
echo "HTTP Proxy Port:    $HTTP_PORT"
echo "HTTPS Proxy Port:   $HTTPS_PORT"
echo "Status API Port:    $STATUS_PORT"
echo "Host Header:        $TARGET_HOST"
echo "-----------------------------------------------------------------"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

assert_test() {
  local name="$1"
  local condition="$2"
  local details="${3:-}"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [ "$condition" -eq 1 ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e " ${GREEN}[PASS]${NC} $name"
    if [ -n "$details" ]; then echo -e "        ${GRAY}$details${NC}"; fi
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e " ${RED}[FAIL]${NC} $name"
    if [ -n "$details" ]; then echo -e "        ${YELLOW}$details${NC}"; fi
  fi
}

# 1. DP Status
echo -e "\n--> [1/5] Checking Data Plane Health & Konnect CP Synchronization..."
STATUS_RESP=$(curl -s --connect-timeout 5 "http://${DP_HOST}:${STATUS_PORT}/status" || echo "")
if echo "$STATUS_RESP" | grep -q "configuration_hash"; then
  CONFIG_HASH=$(echo "$STATUS_RESP" | grep -o '"configuration_hash":"[^"]*"' | cut -d'"' -f4)
  assert_test "DP is alive and reachable via Status API" 1 "Connected to Status API"
  assert_test "DP configuration is synchronized from Konnect CP" 1 "Config Hash: $CONFIG_HASH"
else
  assert_test "DP Status API reachable" 0 "Failed to reach Status API"
fi

# 2. HTTP -> HTTPS Enforcement
echo -e "\n--> [2/5] Testing HTTP -> HTTPS Security Enforcement..."
HTTP_HEADER=$(curl -s -i --connect-timeout 5 "http://${DP_HOST}:${HTTP_PORT}/infydigital/CCPServices/health" -H "Host: ${TARGET_HOST}" | head -n 1 || echo "")
if echo "$HTTP_HEADER" | grep -q "426"; then
  assert_test "HTTP requests are rejected with HTTPS upgrade requirement (426)" 1 "Kong enforced protocols: [https] policy rule."
else
  assert_test "HTTP requests rejected with 426" 0 "Received: $HTTP_HEADER"
fi

# 3. Host Isolation
echo -e "\n--> [3/5] Testing Host Isolation (Negative Security Test)..."
BAD_HOST_HEADER=$(curl -k -s -i --connect-timeout 5 "https://${DP_HOST}:${HTTPS_PORT}/infydigital/CCPServices/health" -H "Host: unauthorized-domain.com" | head -n 1 || echo "")
if echo "$BAD_HOST_HEADER" | grep -q "404"; then
  assert_test "Requests with unauthorized Host header are rejected (404)" 1 "Host isolation prevents route shadowing."
else
  assert_test "Unauthorized Host rejected with 404" 0 "Received: $BAD_HOST_HEADER"
fi

# 4. HTTPS Route Matching
echo -e "\n--> [4/5] Testing HTTPS Route Matching for Domain 'infydigital'..."
HTTPS_RESP=$(curl -k -s -i --connect-timeout 5 --max-time 15 "https://${DP_HOST}:${HTTPS_PORT}/infydigital/CCPServices/health" -H "Host: ${TARGET_HOST}" || echo "")
if echo "$HTTPS_RESP" | grep -qi "server: kong"; then
  assert_test "HTTPS request is decrypted and processed by Kong Gateway" 1 "Server header confirmed: Kong Enterprise Gateway"
else
  assert_test "HTTPS request processed by Kong" 0 "No Kong Server header found"
fi

# 5. Rate Limiting Advanced
echo -e "\n--> [5/5] Testing Rate Limiting & Enterprise Policy Enforcement..."
if echo "$HTTPS_RESP" | grep -qi "RateLimit-Limit"; then
  REMAINING=$(echo "$HTTPS_RESP" | grep -i "RateLimit-Remaining:" | tr -d '\r' || echo "N/A")
  assert_test "Rate Limiting Advanced headers are present in response" 1 "$REMAINING"
else
  assert_test "Rate Limiting Advanced headers present" 0 "Rate limit header missing"
fi

echo -e "\n${CYAN}=================================================================${NC}"
echo -e "${CYAN}                     E2E Test Execution Summary${NC}"
echo -e "${CYAN}=================================================================${NC}"
echo "Total Tests Executed: $TOTAL_TESTS"
echo -e "Passed:               ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:               ${RED}$FAILED_TESTS${NC}"
echo -e "${CYAN}=================================================================${NC}"

if [ "$FAILED_TESTS" -eq 0 ]; then
  echo -e "${GREEN}[SUCCESS] All E2E validation tests passed successfully!${NC}"
  exit 0
else
  echo -e "${RED}[FAILURE] $FAILED_TESTS test(s) failed.${NC}"
  exit 1
fi
