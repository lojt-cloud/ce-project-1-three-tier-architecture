# AWS 3-Tier Architecture — Cost Analysis & Optimization Strategy

This document provides a realistic monthly cost breakdown for running this 3-tier infrastructure in `us-east-1` (N. Virginia) and outlines optimization strategies for production scaling.

---

##  Itemized Monthly Cost Breakdown (Estimated)

*Estimates based on standard AWS `us-east-1` On-Demand pricing assuming 730 hours/month.*

| Service Component                | Configuration Details                      | Hourly Rate                    | Estimated Monthly Cost |

| **EC2 — App Tier (3 instances)** | `t3.micro` (2 vCPU, 1 GB RAM) x 3 instances| $0.0104 / hr / instance            | **$22.78**         |
| **EC2 — Data Tier (1 instance)** | `t3.micro` (2 vCPU, 1 GB RAM)              | $0.0104 / hr                       | **$7.59**          |
| **EC2 — Bastion Host (1 instance)| `t3.micro` (2 vCPU, 1 GB RAM)              | $0.0104 / hr                       | **$7.59**          |
| **EBS Storage**                  | 5 x 8 GB `gp3` volumes (40 GB total)       | $0.08 / GB-month                   | **$3.20**          |
| **Application Load Balancer**    | 1 ALB (Public subnets across 2 AZs)        | $0.0225 / hr + $0.008/LCU-hr       | **$18.00**         |
| **NAT Gateway (1 Gateway)**      | 1 NAT Gateway (`us-east-1a`)               | $0.045 / hr + $0.045 /GB processed | **$32.85(+traffic) |
| **VPC Flow Logs & CloudWatch**   | Custom CloudWatch log group + metrics/alarms | ~$0.50 / GB ingested             | **$3.00**          |
| **Data Transfer**                | Inbound Free; Inter-AZ traffic ($0.01/GB)  | Variable                           | **~$2.00**         |


 **TOTAL ESTIMATED MONTHLY COST**  | **~$97.01 / month** 

---

##  Cost Drivers & Analysis

1. **NAT Gateway (34% of total cost):**
   The single NAT Gateway is the largest fixed monthly expense ($32.85/mo) regardless of traffic volume, charged purely for staying active in the public subnet.

2. **Compute Tier (39% of total cost):**
   Running 5 total `t3.micro` EC2 instances accounts for ~$38.00/mo.

3. **Application Load Balancer (19% of total cost):**
   Fixed base cost of $16.43/mo plus LCU (Load Balancer Capacity Unit) usage.

---

##  Production Cost Optimization Strategies

### 1. Architectural & Compute Optimizations
- **Migrate Bastion to AWS Systems Manager (SSM) Session Manager:**
  Eliminates the dedicated Bastion EC2 instance entirely, saving **~$8.00/month** and improving security by removing inbound port 22 access.

- **Auto Scaling Group (ASG) Schedule & Dynamic Sizing:**
  Configure scheduled scaling policies to reduce the App Tier from 3 instances down to 1 during off-peak hours (e.g., midnight to 6 AM), saving up to 25% on App tier compute costs.

- **Compute Savings Plans / Reserved Instances (RIs):**
  Committing to a 1-year or 3-year Savings Plan for baseline compute capacity yields up to **30%–40% discount** on EC2 instances.

### 2. Networking & Data Transfer Optimizations
- **VPC Endpoints for AWS Services:**
  If app instances need to communicate with S3 or DynamoDB, route traffic via free **Gateway VPC Endpoints** rather than traversing the NAT Gateway ($0.045/GB saved).
  
- **Single NAT Gateway vs Multi-AZ NAT Gateway Trade-off:**
  For strict production SLA, deploying 2 NAT Gateways (1 per AZ) doubles NAT costs to ~$65.70/mo. For non-production or cost-sensitive setups, keeping 1 NAT Gateway accepts cross-AZ data transfer fees ($0.01/GB) while saving $32.85/month.

### 3. Log Retention & CloudWatch Cleanup
- Set explicit CloudWatch Log retention policies (e.g., 7 or 14 days for VPC Flow Logs and App logs) rather than "Never Expire" to prevent unbounded storage charges over time.