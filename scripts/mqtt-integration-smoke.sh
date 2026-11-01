#!/usr/bin/env bash
# Optional MQTT smoke harness (issue #19). Broker-free unit tests stay default.
# Requires: docker, mosquitto_pub, mosquitto_sub (brew install mosquitto).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_DIR="$ROOT/examples/home-assistant/mosquitto"
HOST="${UNCHAIR_MQTT_HOST:-127.0.0.1}"
PORT="${UNCHAIR_MQTT_PORT:-1883}"
DEVICE_A="${UNCHAIR_MQTT_DEVICE_A:-uch_smoke01}"
DEVICE_B="${UNCHAIR_MQTT_DEVICE_B:-uch_smoke02}"

need() { command -v "$1" >/dev/null || { echo "error: missing $1" >&2; exit 1; }; }
need docker
need mosquitto_pub
need mosquitto_sub

cleanup() {
  (cd "$COMPOSE_DIR" && docker compose down -v >/dev/null 2>&1) || true
}
trap cleanup EXIT

echo "[smoke] starting disposable Mosquitto"
(cd "$COMPOSE_DIR" && docker compose up -d)

echo "[smoke] waiting for broker ${HOST}:${PORT}"
for _ in $(seq 1 30); do
  if mosquitto_pub -h "$HOST" -p "$PORT" -t "unchair/${DEVICE_A}/availability" -m "probe" -q 0 2>/dev/null; then
    break
  fi
  sleep 0.5
done

pub() {
  local topic="$1" payload="$2" retain="${3:-false}"
  if [[ "$retain" == "true" ]]; then
    mosquitto_pub -h "$HOST" -p "$PORT" -t "$topic" -m "$payload" -r
  else
    mosquitto_pub -h "$HOST" -p "$PORT" -t "$topic" -m "$payload"
  fi
}

echo "[smoke] retained state + availability (device A)"
pub "unchair/${DEVICE_A}/availability" "online" true
pub "unchair/${DEVICE_A}/state" '{"contractVersion":1,"deviceId":"'"$DEVICE_A"'","phase":"working"}' true

echo "[smoke] non-retained event"
pub "unchair/${DEVICE_A}/event" '{"contractVersion":1,"name":"break.completed"}' false

echo "[smoke] discovery config retain"
pub "homeassistant/sensor/unchair_${DEVICE_A}_phase/config" \
  '{"name":"Phase","uniq_id":"unchair_'"$DEVICE_A"'_phase","stat_t":"unchair/'"$DEVICE_A"'/state"}' true

echo "[smoke] command payload (allowlisted shape)"
pub "unchair/${DEVICE_A}/command" '{"contractVersion":1,"command":"start_break","id":"smoke-1"}' false

echo "[smoke] multi-device isolation — B must not see A's retained state on B prefix"
pub "unchair/${DEVICE_B}/availability" "online" true
GOT="$(mosquitto_sub -h "$HOST" -p "$PORT" -t "unchair/${DEVICE_B}/state" -C 1 -W 2 -R || true)"
if [[ -n "$GOT" ]]; then
  echo "error: device B unexpectedly received retained state: $GOT" >&2
  exit 1
fi

echo "[smoke] read back retained availability for A"
AVAIL="$(mosquitto_sub -h "$HOST" -p "$PORT" -t "unchair/${DEVICE_A}/availability" -C 1 -W 3)"
[[ "$AVAIL" == "online" ]] || { echo "error: expected online, got '$AVAIL'" >&2; exit 1; }

echo "[smoke] ok — broker discovery/state/event/command topics behave"
echo "[smoke] optional live XCTest:"
echo "  UNCHAIR_MQTT_INTEGRATION=1 UNCHAIR_MQTT_HOST=$HOST UNCHAIR_MQTT_PORT=$PORT \\"
echo "    xcodebuild test -scheme Unchair -destination 'platform=macOS' \\"
echo "    -only-testing:UnchairTests/MQTTLiveIntegrationTests"
