# AWS 3-Tier Cloud Architecture — System Design & Engineering Rationale

This document provides a comprehensive technical breakdown of the production-leaning 3-tier architecture built on AWS (`proj1-vpc`). It covers component specifications, network design trade-offs, defense-in-depth security modeling, high availability (HA) engineering, and architectural reflection.

---

##  1. Detailed Architecture Overview

The system is structured across three distinct functional tiers distributed across two Availability Zones (`us-east-1a` and `us-east-1b`) within the primary project VPC (`vpc-01bfe876108cc219b`).

```text
                                  [ Internet Clients ]
                                           │
                                           ▼ (Port 80 HTTP)
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ TIER 1: PRESENTATION (Public Subnets: 10.0.1.0/24 [1a], 10.0.2.0/24 [1b])              │
│                                                                                        │
│                     Internet-Facing Application Load Balancer                          │
│                   (proj1-alb-336927573.us-east-1.elb.amazonaws.com)                    │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │
                                           │ Forward Traffic (Port 80)
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ TIER 2: APPLICATION (Private Subnets: 10.0.11.0/24 [1a], 10.0.12.0/24 [1b])            │
│                                                                                        │
│                 Auto Scaling Group (Desired: 2-3 | Min: 2 | Max: 6)                    │
│             Node.js Web App Servers (Express.js) + IMDSv2 Enabled                      │
│             Scale-Out Policy: Target Tracking (CPUUtilization > 60%)                   │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │
                                           │ Internal Probe / Query (Port 3306)
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ TIER 3: DATA (Isolated Private Subnets: 10.0.21.0/24 [1a], 10.0.22.0/24 [1b])          │
│                                                                                        │
│                       Simulated Database Instance (10.0.21.10)                         │
│                    Strict Layer-3 Air-Gap (No Internet Route)                          │
└────────────────────────────────────────────────────────────────────────────────────────┘

                           ┌───────────────────────────────┐
                           │  Bastion Host (Public Subnet) │
                           │  10.0.1.x / Public Elastic IP │
                           │ SSH Access: 143.179.136.227/32│
                           └───────────────┬───────────────┘
                                           │ SSH Jump (Port 22)
                                           ▼
                               [ App & Data Tier Management ]




## 2. Component Descriptions & Specifications

1. Presentation Layer (Tier 1)
Application Load Balancer (ALB):

DNS Name: proj1-alb-336927573.us-east-1.elb.amazonaws.com

VPC ID: vpc-01bfe876108cc219b (proj1-vpc)

Scheme: internet-facing

Subnets: public-subnet-1a (10.0.1.0/24), public-subnet-1b (10.0.2.0/24 / subnet-02c09f7a40802b159)

Function: Serves as the single public point of entry, balancing external HTTP traffic across healthy application targets using round-robin distribution. Evaluates instance health via a HTTP /health probe every 30 seconds.

2. Application Layer (Tier 2)
Node.js Express App Instances:

Subnets: app-subnet-1a (10.0.11.0/24), app-subnet-1b (10.0.12.0/24)

Compute: t3.micro EC2 instances launched via Launch Template.

App Stack: Node.js HTTP server rendering dynamic JSON endpoints (/, /health, /api/stats). Probes the database tier dynamically using native TCP socket verification (net.Socket()) on port 3306.

Auto Scaling Group (ASG): Configured with a minimum of 2 instances and target tracking CPU scaling. Automatically provisions or terminates instances based on load.

3. Data Layer (Tier 3)
Database Server:

Subnets: data-subnet-1a (10.0.21.0/24), data-subnet-1b (10.0.22.0/24)

Private IP: 10.0.21.10

Function: Serves as the internal data storage tier listening on TCP port 3306. Completely inaccessible from the external internet.


4. Management & Operational Infrastructure
Bastion Jump Host:

Location: public-subnet-1a (10.0.1.0/24)

Purpose: Provides controlled out-of-band SSH access to private instances without exposing private application nodes to the public internet. Uses SSH key agent forwarding (ssh -A).

NAT Gateway:

Location: public-subnet-1a (10.0.1.0/24)

Purpose: Grants outbound-only internet connectivity for private application instances to fetch software packages and security updates.

## 3. Network Design Rationale

Subnet Segmentation
The network architecture divides the /16 IPv4 CIDR block (10.0.0.0/16) of proj1-vpc (vpc-01bfe876108cc219b) into six dedicated /24 subnets across two Availability Zones:
Subnet Name	      CIDR Block	     AZ	        Tier	        Internet Accessibility
public-subnet-1a	10.0.1.0/24	  us-east-1a	Presentation	Direct (Internet Gateway)
public-subnet-1b	10.0.2.0/24	  us-east-1b	Presentation	Direct (Internet Gateway)
app-subnet-1a	    10.0.11.0/24	us-east-1a	Application	  Outbound Only (NAT Gateway)
app-subnet-1b	    10.0.12.0/24	us-east-1b	Application	  Outbound Only (NAT Gateway)
data-subnet-1a	  10.0.21.0/24	us-east-1a	  Data	      Air-Gapped (No Internet Route)
data-subnet-1b	  10.0.22.0/24	us-east-1b	  Data	      Air-Gapped (No Internet Route)

Routing Table Strategy
Public Route Table: Routes 0.0.0.0/0 directly to the attached Internet Gateway (igw-xxx).

Private Application Route Table: Routes 0.0.0.0/0 to the NAT Gateway (nat-xxx), allowing outbound package installations while preventing inbound initiation.

Isolated Data Route Table: Contains only the local route (10.0.0.0/16 local). This guarantees at the network routing layer (Layer 3) that database traffic can never leave the VPC or communicate with the internet.

## 4. Security Strategy
The platform implements a Defense-in-Depth security framework operating across multiple infrastructure boundaries:

Least-Privilege Security Group Chaining:
Security groups reference other Security Group IDs rather than CIDR blocks.

alb-sg accepts HTTP from 0.0.0.0/0.

app-tier-sg accepts HTTP only from alb-sg.

data-tier-sg accepts TCP 3306 only from app-tier-sg.

Administrative Access Lockdown:

Inbound SSH (Port 22) on the Bastion Host is restricted to a single /32 administrator IP (143.179.136.227/32).

SSH agent forwarding ensures private SSH keys never reside on intermediate cloud servers.

IMDSv2 Enforcement:
All EC2 instances enforce Instance Metadata Service v2 (token-based header auth), preventing Server-Side Request Forgery (SSRF) credential theft.

VPC Flow Logging:
All IPv4 packet flows are recorded and delivered to CloudWatch Log Group /aws/vpc/proj1-flow-logs for compliance auditing.

## 5. High Availability & Resilience Approach
Multi-AZ Redundancy
Load Balancing: The ALB spans two independent physical Availability Zones (us-east-1a and us-east-1b). If one zone experiences an outage, traffic automatically routes to healthy targets in the remaining zone.

Compute Tier Auto Scaling: The ASG balances instance distribution evenly across both private subnets (app-subnet-1a and app-subnet-1b).

Fault Recovery & Health Checks
Target Group Probes: The ALB checks /health on all registered targets. If a node fails two consecutive health checks, it is removed from the rotation immediately.

Self-Healing Infrastructure: The Auto Scaling Group replaces terminated or unhealthy instances automatically to maintain the minimum desired capacity.

## 6. Architectural Reflections & Trade-Offs
Monolith vs. 3-Tier Architecture
Trade-Off: A monolithic single-server deployment is easier and cheaper to run initially, but introduces a single point of failure and scales inefficiently.

Why 3-Tier Wins: Decoupling web, app, and data tiers allows independent scaling, limits security blast radius, and aligns with production cloud engineering standards.

Single NAT Gateway vs. Multi-AZ NAT Gateway
Trade-Off: A single NAT Gateway creates a cross-AZ dependency for instances in us-east-1b and presents a single point of failure for outbound internet traffic.

Decision: A single NAT Gateway was chosen for cost optimization (~$32.85/month savings) during this lab build, while acknowledging that a dual-NAT setup is required for high-SLA enterprise production.