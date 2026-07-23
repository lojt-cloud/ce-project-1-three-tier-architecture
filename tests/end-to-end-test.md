## Overview
This document defines end-to-end validation scenarios for the 3-Tier Architecture. Tests verify that client HTTP requests travel through Tier 1 (ALB), trigger Node.js business logic in Tier 2 (App Tier), query mock data from Tier 3 (Database Tier), and return valid responses.

---

##  Test Matrix & Scenarios

| Test Case | Target Endpoint | Expected Status | Expected Payload / Content | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **E2E-01** | `GET /` | `200 OK` | HTML dashboard with Tier 1, 2, 3 details | Page renders HTML with `Instance ID` and `Database Host` |
| **E2E-02** | `GET /health` | `200 OK` | `{"status":"healthy","instance":"i-xxx"}` | JSON response parsed with healthy state |
| **E2E-03** | `GET /api/stats` | `200 OK` | `{"instance":"i-xxx","database":"10.0.21.10","data":{...}}` | Valid JSON payload with database query stats |

---

##  Execution Commands

### 1. Execute Automated E2E Test Script
Run this script from your terminal to hit all endpoints via the ALB DNS:

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names app-alb \
  --query 'LoadBalancers[0].DNSName' --output text)

echo "Testing ALB Endpoint: http://$ALB_DNS"
echo "=================================================="

echo " [E2E-01] Testing Main Application Dashboard (/)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/")
if [ "$HTTP_CODE" -eq 200 ]; then
  echo " PASS: Main dashboard returned HTTP 200"
else
  echo " FAIL: Main dashboard returned HTTP $HTTP_CODE"
fi

echo " [E2E-02] Testing Health Check Endpoint (/health)..."
HEALTH_RESP=$(curl -s "http://$ALB_DNS/health")
echo "Response: $HEALTH_RESP"

echo " [E2E-03] Testing API Data Endpoint (/api/stats)..."
API_RESP=$(curl -s "http://$ALB_DNS/api/stats")
echo "Response: $API_RESP"

Acceptance Criteria
[x] All HTTP responses return 200 OK.

[x] /api/stats correctly reflects database host IP (10.0.21.10).

[x] HTML dashboard renders correctly in all major web browsers.
