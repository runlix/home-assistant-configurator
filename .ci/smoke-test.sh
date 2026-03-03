#!/usr/bin/env bash
set -e
set -o pipefail

# Smoke test for home-assistant-configurator Docker image
# This script receives IMAGE_TAG from the workflow environment

IMAGE="${IMAGE_TAG}"
PLATFORM="${PLATFORM:-linux/amd64}"
CONTAINER_NAME="home-assistant-configurator-smoke-test-${RANDOM}"
HC_PORT="3218"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 Home Assistant Configurator Smoke Test${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Image: ${IMAGE}"
echo "Platform: ${PLATFORM}"
echo ""

if [ -z "${IMAGE}" ] || [ "${IMAGE}" = "null" ]; then
  echo -e "${RED}❌ ERROR: IMAGE_TAG environment variable is not set${NC}"
  exit 1
fi

CONFIG_DIR=$(mktemp -d)
chmod 777 "${CONFIG_DIR}"
echo "Config directory: ${CONFIG_DIR}"
echo ""

cleanup() {
  echo ""
  echo -e "${YELLOW}🧹 Cleaning up...${NC}"

  if docker ps -a | grep -q "${CONTAINER_NAME}"; then
    echo "Saving container logs..."
    docker logs "${CONTAINER_NAME}" > /tmp/home-assistant-configurator-smoke-test.log 2>&1 || true
    echo "Logs saved to: /tmp/home-assistant-configurator-smoke-test.log"
  fi

  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true

  if [ -d "${CONFIG_DIR}" ]; then
    chmod -R 777 "${CONFIG_DIR}" 2>/dev/null || true
    rm -rf "${CONFIG_DIR}" 2>/dev/null || true
  fi

  echo -e "${YELLOW}Cleanup complete${NC}"
}
trap cleanup EXIT

echo -e "${BLUE}▶️  Starting container...${NC}"
if ! docker run \
  --pull=never \
  --platform="${PLATFORM}" \
  --name "${CONTAINER_NAME}" \
  -v "${CONFIG_DIR}:/config" \
  -p "${HC_PORT}:3218" \
  -e TZ=UTC \
  -d \
  "${IMAGE}"; then
  echo -e "${RED}❌ Failed to start container${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Container started${NC}"
echo ""

echo -e "${BLUE}⏳ Waiting for configurator to initialize...${NC}"
echo "Waiting 10 seconds for startup..."
sleep 10

echo ""
echo -e "${BLUE}🔍 Checking container status...${NC}"
if ! docker ps | grep -q "${CONTAINER_NAME}"; then
  echo -e "${RED}❌ Container exited unexpectedly${NC}"
  echo ""
  echo "Container logs:"
  docker logs "${CONTAINER_NAME}" 2>&1
  exit 1
fi
echo -e "${GREEN}✅ Container is running${NC}"
echo ""

echo -e "${BLUE}📋 Analyzing container logs...${NC}"
LOGS=$(docker logs "${CONTAINER_NAME}" 2>&1)

FATAL_COUNT=$(echo "$LOGS" | grep -ciE "fatal|panic|traceback|exception" || true)
if [ "${FATAL_COUNT}" -gt 0 ]; then
  echo -e "${RED}❌ Found ${FATAL_COUNT} critical error(s) in logs:${NC}"
  echo "$LOGS" | grep -iE "fatal|panic|traceback|exception" | head -10
  exit 1
fi

echo -e "${GREEN}✅ No critical errors in logs${NC}"
echo ""

echo -e "${BLUE}🌐 Testing web endpoint...${NC}"
ROOT_URL="http://localhost:${HC_PORT}/"
MAX_ATTEMPTS=24
ATTEMPT=0
WEB_OK=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${ROOT_URL}" 2>/dev/null || echo "000")
  if [ "${HTTP_CODE}" = "200" ] || [ "${HTTP_CODE}" = "401" ] || [ "${HTTP_CODE}" = "403" ]; then
    WEB_OK=true
    echo -e "${GREEN}✅ Web endpoint responding (${ROOT_URL}) HTTP ${HTTP_CODE}${NC}"
    break
  fi

  echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: Waiting for web endpoint... (HTTP ${HTTP_CODE})"
  sleep 5
done

if [ "${WEB_OK}" = false ]; then
  echo -e "${RED}❌ Web endpoint check failed after ${MAX_ATTEMPTS} attempts${NC}"
  echo ""
  echo "Recent container logs:"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -30
  exit 1
fi
echo ""

echo -e "${BLUE}🏗️  Verifying architecture...${NC}"
IMAGE_ARCH=$(docker image inspect "${IMAGE}" | jq -r '.[0].Architecture')
EXPECTED_ARCH=$(echo "${PLATFORM}" | cut -d'/' -f2)

if [ "${IMAGE_ARCH}" = "${EXPECTED_ARCH}" ] || [ "${IMAGE_ARCH}" = "null" ]; then
  if [ "${IMAGE_ARCH}" = "null" ]; then
    echo -e "${YELLOW}⚠️  Cannot verify architecture (not set in image metadata)${NC}"
  else
    echo -e "${GREEN}✅ Architecture matches: ${IMAGE_ARCH}${NC}"
  fi
else
  echo -e "${RED}❌ Architecture mismatch: expected ${EXPECTED_ARCH}, got ${IMAGE_ARCH}${NC}"
  exit 1
fi
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅✅✅ Smoke Test PASSED ✅✅✅${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Test Summary:"
echo "  • Container started successfully"
echo "  • No critical errors in logs"
echo "  • Web endpoint responding"
echo "  • Correct architecture: ${IMAGE_ARCH}"
echo ""

exit 0
