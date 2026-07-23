# Security Architecture & Defense-in-Depth Strategy

This document details the security design, network isolation model, security group chaining rules, IAM policies, applied security best practices, and vulnerability mitigations for the 3-tier AWS deployment.

---

##  1. Network Isolation Strategy

The architecture employs a strict **Defense-in-Depth** network isolation model across three distinct subnet tiers and two Availability Zones (`us-east-1a`, `us-east-1b`).

```text
[ Internet ] ──(80/443)──> [ Public Subnet / ALB ] ──(80)──> [ Private App Subnet ] ──(3306)──> [ Isolated Data Subnet ]
                                  │                                  │                                  │
                          IGW Route (0.0.0.0/0)              NAT Route (0.0.0.0/0)              LOCAL Route ONLY

## Routing Layer Isolation
Public Subnet Tier (10.0.1.0/24, 10.0.2.0/24):

Attached to an Internet Gateway (IGW).

Houses the Application Load Balancer (ALB) and Bastion Host.

Only tier with public IPv4 addresses assigned.

Application Private Subnet Tier (10.0.11.0/24, 10.0.12.0/24):

Routed to a NAT Gateway for outbound internet access (e.g., OS updates, package management).

Zero public IP addresses assigned. Unreachable from the internet.

Data Isolated Subnet Tier (10.0.21.0/24, 10.0.22.0/24):

Air-Gapped Routing: The route table contains no default route (0.0.0.0/0).

Cannot communicate with the internet in either direction, regardless of security group rules.

Enforces absolute network isolation at Layer 3

2. Security Group Chaining & Rules (All Tiers)
Security groups enforce strict Least Privilege by referencing Security Group IDs (SG-IDs) instead of open CIDR ranges for internal communication.

Plaintext
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│  proj1-alb-sg   │ ────> │proj1-app-tier-sg│ ────> │proj1-data-tier-sg│
│sg-09753d7d5333d │       │sg-0d7c27a50e69b │       │sg-0fa3145b2e634 │
└─────────────────┘       └─────────────────┘       └─────────────────┘
                                   ▲                         ▲
                                   │ (Port 22 SSH)           │ (Port 22 SSH)
                          ┌─────────────────┐                │
                          │proj1-bastion-sg │ ───────────────┘
                          │sg-052f149f8658f │
                          └─────────────────┘

## Complete Security Group Rule Matrix

|  Security Group        |           Group ID     | Direction   | Protocol / Port | Source / Destination |       Purpose      |
| **`proj1-alb-sg`**     | `sg-09753d7d5333db81c` | **Inbound** | TCP 80 (HTTP)   | `0.0.0.0/0`          | Public Web Traffic |

| | | **Inbound** | TCP 443 (HTTPS) | `0.0.0.0/0` | Public Secure Web Traffic |
| | | **Outbound**| TCP 80 | `sg-0d7c27a50e69b5f9e` (`app-tier-sg`) | Forward HTTP to App Instances |

| **`proj1-app-tier-sg`**| `sg-0d7c27a50e69b5f9e` | **Inbound** |    TCP 80       | `sg-09753d7d5333db81c`(`alb-sg`)| accept only traffic from ALB |


| | | **Inbound** | TCP 22 (SSH) | `sg-052f149f8658f9922` (`bastion-sg`) | Admin access ONLY from Bastion |
| | | **Outbound**| TCP 3306 (MySQL) | `sg-0fa3145b2e6343ca8` (`data-tier-sg`) | Query Database Tier |
| | | **Outbound**| TCP 80 / 443 | `0.0.0.0/0` (via NAT) | Package updates / npm dependencies |

| **`proj1-data-tier-sg`**| `sg-0fa3145b2e6343ca8` | **Inbound** | TCP 3306 (MySQL) | `sg-0d7c27a50e69b5f9e` (`app-tier-sg`) | DB Queries 

ONLY from App Tier |
| | | **Inbound** | TCP 5432 (PostgreSQL)| `sg-0d7c27a50e69b5f9e` (`app-tier-sg`) | Alternative DB Port |
| | | **Inbound** | TCP 22 (SSH) | `sg-052f149f8658f9922` (`bastion-sg`) | Admin access ONLY from Bastion |
| | | **Outbound**| None | None | No outbound traffic initiated |
| **`proj1-bastion-sg`**| `sg-052f149f8658f9922` | **Inbound** | TCP 22 (SSH) | `143.179.136.227/32` | SSH locked to trusted operator IP |
| | | **Outbound**| TCP 22 (SSH) | `sg-0d7c27a50e69b5f9e`, `sg-0fa3145b2e6343ca8` | SSH jump access to App & Data tiers |



## 🔑 3. IAM Roles and Policies

Identity and Access Management (IAM) controls service-to-service authorization without hardcoding credentials on servers.

### 1. VPC Flow Logs IAM Role & Trust Policy (`flow-logs-trust.json`)
Allows AWS VPC Flow Logs service to publish network traffic logs directly to CloudWatch Log Group `/aws/vpc/proj1-flow-logs`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
2. EC2 Instance Metadata Service v2 (IMDSv2) Policy

All EC2 instances enforce IMDSv2 (Token-backed metadata service):

Requires a session token header (X-aws-ec2-metadata-token) for metadata requests.



---
##  5. Potential Vulnerabilities & Mitigations

| Identified Threat / Vulnerability   | Risk Level | Current Defense / Mitigation                                  |                  Recommended Long-Term Upgrade                                          |

| **Port 22 SSH Exposure on Bastion** | Medium    | Inbound traffic locked strictly to single `/32` operator IP.   | Migrate to **AWS Systems Manager (SSM) Session Manager** to eliminate port 22 entirely. |
| **Unencrypted HTTP (Port 80)**      | Medium    | ALB listens on Port 80 for lab simplicity.                     | Attach an **ACM SSL/TLS Certificate** and enforce HTTPS (Port 443) redirection.         |
| **Single NAT Gateway Failure**      | Medium    | Highly resilient within `us-east-1a`; non-crit failure.        | Deploy a **Multi-AZ NAT Gateway** setup (1 per AZ) for strict SLAs.                     |
| **Single Database EC2 Instance**    | High      | Isolated routing prevents unauthorized external network access | Replace single EC2 DB host with **Amazon RDS Multi-AZ** for active/standby replication. |
| **Application Layer DDoS**          | Low/Med   | ALB buffers incoming connections across instances.             | Attach **AWS WAF (Web Application Firewall)** to ALB to filter SQLi and XSS attempts.   |