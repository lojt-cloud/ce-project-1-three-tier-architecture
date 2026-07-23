#!/bin/bash
# ==============================================================================
# 💾 Tier 3 Database Diagnostic & Simulator Utility (db-sim.sh)
# ==============================================================================
# Purpose:
# 1. Tests network & TCP port 3306 reachability from App Tier to Database Tier.
# 2. Generates mock database data payloads matching Node.js server.js endpoints.
# 3. Provides a lightweight Python mock server for port 3306 testing.
# ==============================================================================

DB_HOST="${DB_HOST:-10.0.21.10}"
DB_PORT="${DB_PORT:-3306}"

echo "=================================================="
echo "💾 Tier 3 Data Layer Diagnostic & Simulator"
echo "=================================================="
echo "Target Database Host: $DB_HOST"
echo "Target Port:          $DB_PORT"
echo "--------------------------------------------------"

# 1. Test ICMP Ping Connectivity
check_ping() {
  echo "📡 Testing ICMP Ping to $DB_HOST..."
  if ping -c 2 -W 2 "$DB_HOST" >/dev/null 2>&1; then
    echo "✅ SUCCESS: Database Host responded to ICMP Ping!"
  else
    echo "⚠️ WARNING: ICMP Ping failed to $DB_HOST."
  fi
}

# 2. Test TCP Port 3306 Reachability
check_connectivity() {
  echo "🔍 Testing TCP connectivity to $DB_HOST on port $DB_PORT..."
  
  if command -v nc >/dev/null 2>&1; then
    nc -z -w 3 "$DB_HOST" "$DB_PORT" >/dev/null 2>&1
    STATUS=$?
  elif command -v timeout >/dev/null 2>&1; then
    timeout 3 bash -c "</dev/tcp/$DB_HOST/$DB_PORT" >/dev/null 2>&1
    STATUS=$?
  else
    python3 -c "import socket; s = socket.socket(); s.settimeout(3); exit(s.connect_ex(('$DB_HOST', $DB_PORT)))" >/dev/null 2>&1
    STATUS=$?
  fi

  if [ $STATUS -eq 0 ]; then
    echo "✅ SUCCESS: Port $DB_PORT is OPEN on $DB_HOST!"
    return 0
  else
    echo "⚠️ WARNING: Unable to establish TCP connection to $DB_HOST:$DB_PORT."
    echo "   (Check that db-tier-sg authorizes port 3306 from app-tier-sg)"
    return 1
  fi
}

# 3. Generate Simulated Database JSON Response
generate_payload() {
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat << PAYLOAD
{
  "status": "connected",
  "database_host": "$DB_HOST",
  "port": $DB_PORT,
  "data": {
    "users": 42,
    "posts": 156,
    "active_sessions": 12,
    "last_sync": "$TIMESTAMP"
  }
}
PAYLOAD
}

# Main Execution Routing
case "$1" in
  --test|test)
    check_ping
    echo "--------------------------------------------------"
    check_connectivity
    ;;
  --json|json)
    generate_payload
    ;;
  --serve|serve)
    echo "🚀 Starting mock DB socket listener on port $DB_PORT..."
    python3 -c "
import socket, json, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', $DB_PORT))
s.listen(5)
print('Mock DB Server running on port $DB_PORT...')
while True:
    conn, addr = s.accept()
    data = {'status':'healthy','host':'$DB_HOST','users':42,'posts':156,'time':time.time()}
    conn.sendall(json.dumps(data).encode() + b'\n')
    conn.close()
"
    ;;
  *)
    check_ping
    echo "--------------------------------------------------"
    check_connectivity
    echo "--------------------------------------------------"
    echo "📊 Simulated DB Payload Output:"
    generate_payload
    echo "--------------------------------------------------"
    echo "Usage Options:"
    echo "  ./app/db-sim.sh test   - Test ICMP & TCP port 3306 reachability"
    echo "  ./app/db-sim.sh json   - Output simulated database JSON payload"
    echo "  ./app/db-sim.sh serve  - Run mock DB server on port 3306"
    ;;
esac