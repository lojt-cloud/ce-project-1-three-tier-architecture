
#  Security & Network Isolation Test Suite

## Overview
This suite performs negative and boundary security testing to verify that Tier 2 (Application) and Tier 3 (Database) resources are strictly insulated from unauthorized ingress and direct internet access.

---

##  Security Test Cases

| Test ID | Objective | Test Procedure | Expected Outcome | Result |
| :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | Verify App Servers have no Public IP addresses | Query EC2 instances in `app-tier` for public IPv4 assignments | `PublicIp` attribute is `null` or `None` | **PASS** |
| **SEC-02** | Verify DB Server has no Public IP address | Query EC2 instance in `db-tier` for public IPv4 assignment | `PublicIp` attribute is `null` or `None` | **PASS** |
| **SEC-03** | Verify Direct Internet to App Ingress is Blocked | Attempt direct connection to private App Server IPs from local network | Connection Timeout / Unreachable | **PASS** |
| **SEC-04** | Verify Security Group Chaining (`app-tier-sg`) | Verify `app-tier-sg` inbound rules strictly require `alb-sg` source group | Ingress restricted to `alb-sg` ID only | **PASS** |
| **SEC-05** | Verify Security Group Chaining (`db-tier-sg`) | Verify `db-tier-sg` inbound rules strictly require `app-tier-sg` source group | Ingress restricted to `app-tier-sg` ID only | **PASS** |

---

##  Verification Commands

### 1. Verify Public IP Absence Across Tiers 2 & 3
```bash
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=vpc-04ab384385311bf3a" \
  --query "Reservations[*].Instances[*].{Name:Tags[?Key=='Name'].Value|[0], PrivateIP:PrivateIpAddress, PublicIP:PublicIpAddress}" \
  --output table
### 2. Inspect Ingress Rule Sources for Security Group Chaining

VPC_ID="vpc-04ab384385311bf3a"

echo "=== APP TIER SG INGRESS RULES ==="
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=app-tier-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].IpPermissions"

echo "=== DB TIER SG INGRESS RULES ==="
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=db-tier-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].IpPermissions"


### Pass Criteria
[x] Zero public IPv4 addresses assigned to instances in private or isolated subnets.

[x] Ingress rules utilize Security Group ID references rather than open CIDR ranges (0.0.0.0/0).
