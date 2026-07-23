#  Traffic Flow & Load Balancing Test Suite

## Overview
This document evaluates traffic routing efficiency across Availability Zones, verifying round-robin distribution by the Application Load Balancer (ALB) and active target health probe monitoring.

---

##  Traffic Flow Test Cases

### 1. Round-Robin Distribution Verification
Sends multiple sequential requests to the ALB endpoint and captures the serving instance ID to confirm load balancing across Availability Zones (`app-server-1a` and `app-server-1b`).

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names app-alb \
  --query 'LoadBalancers[0].DNSName' --output text)

echo "Testing Traffic Distribution via $ALB_DNS..."
echo "--------------------------------------------------"

for i in {1..6}; do
  INSTANCE_ID=$(curl -s "http://$ALB_DNS/api/stats" | grep -o '"instance":"[^"]*"' | cut -d'"' -f4)
  echo "Request $i handled by Instance: $INSTANCE_ID"
  sleep 1
done

### 2. Target Group Health Status Audit

Checks that the ALB health probes are actively receiving HTTP 200 status responses from /health on port 80.

Bash
TG_ARN=$(aws elbv2 describe-target-groups \
  --names app-target-group \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --query "TargetHealthDescriptions[*].{InstanceId:Target.Id, HealthState:TargetHealth.State, HealthReason:TargetHealth.Reason}" \
  --output table

Expected Behavioral Flow

Client Request ──> ALB (Port 80)
                    ├── Request 1 ──> app-server-1a (10.0.11.x) ──> Return HTTP 200
                    └── Request 2 ──> app-server-1b (10.0.12.x) ──> Return HTTP 200


Acceptance Criteria
[x] Sequential requests alternate between available instances across Availability Zones.

[x] All targets in app-target-group report healthy state under target health checks.