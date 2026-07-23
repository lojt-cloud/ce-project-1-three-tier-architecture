# AWS 3-Tier Architecture — Architectural Improvements & Future Roadmap

This document details short-term technical enhancements, security modernizations, and a proposal for a multi-region disaster recovery architecture.

---

##  Short-Term & Security Modernizations

### 1. Replace Bastion Host with AWS Systems Manager (SSM) Session Manager

* **Current State:** 
A dedicated Bastion EC2 host in a public subnet allows SSH access (Port 22) from a trusted IP address.

* **Proposed Enhancement:** 
Enable the AWS Systems Manager (SSM) agent on private App and DB instances and attach the `AmazonSSMManagedInstanceCore` IAM policy.

* **Benefits:**
 
  - **Zero Inbound Ports:** 
  Eliminates port 22 inbound entirely from all security groups.
  
  - **No Public IP Needed:** 
  Instances remain 100% private.
  
  - **Centralized Audit Logging:** 
  Every terminal command is logged directly to AWS CloudWatch or S3.
  
  - **Cost Elimination:**
   Removes the Bastion EC2 instance cost ($7.59/mo).

### 2. Database Layer Upgrade (Amazon RDS Multi-AZ)
* **Current State:** 
Single EC2 instance running a simulated database process.

* **Proposed Enhancement:** 
Migrate to Amazon RDS for MySQL/PostgreSQL deployed in Multi-AZ configuration across `data-subnet-1a` and `data-subnet-1b`.

* **Benefits:** 
Automatic failover, automated snapshots, storage auto-scaling, and managed security patches.

### 3. HTTPS / TLS Termination via AWS Certificate Manager (ACM)
* **Current State:** 
ALB listens on HTTP (Port 80).

* **Proposed Enhancement:** 
Provision an SSL/TLS certificate via ACM, configure an HTTPS (Port 443) listener on the ALB, and enforce an HTTP-to-HTTPS redirect rule on Port 80.

### 4. Infrastructure as Code (IaC) Adoption
* **Current State:** 
Manual / AWS CLI provisioning.

* **Proposed Enhancement:** 
Codify the full VPC, Security Groups, ALB, and ASG resources using **Terraform** or **AWS CloudFormation** to enable rapid, repeatable environment teardown and reconstruction.

---

##  Multi-Region Disaster Recovery (DR) Architecture Strategy

To transform this single-region architecture into a resilient enterprise-grade solution across regions (e.g., Primary: `us-east-1`, Secondary: `us-west-2`):

```text
               [ Amazon Route 53 (Latency / Failover Routing) ]
                                     │
           ┌─────────────────────────┴─────────────────────────┐
           ▼ (Primary)                                         ▼ (Passive / Secondary)
┌──────────────────────────────────────┐            ┌──────────────────────────────────────┐
│ REGION 1: us-east-1                  │            │ REGION 2: us-west-2                  │
│  - Public Load Balancer              │            │  - Public Load Balancer              │
│  - App ASG (Min: 2, Active)          │            │  - App ASG (Min: 0 or 1 Warm)        │
│  - Amazon Aurora Primary (Read/Write)│──Replic.──>│  - Amazon Aurora Read Replica        │
└──────────────────────────────────────┘            └──────────────────────────────────────┘


## DR Strategy: Pilot Light / Warm Standby
DNS Routing: 
Use Amazon Route 53 with Health Checks to automatically fail over traffic from us-east-1 to us-west-2 if the primary ALB becomes unreachable.

Database Cross-Region Replication: 
Deploy Amazon Aurora Global Database. Writes occur in us-east-1 and asynchronously replicate to us-west-2 with sub-second latency.

Compute Sizing: 
Keep the secondary region ASG at 0 or 1 minimum instance ("Pilot Light") to minimize idle compute costs, expanding to full capacity automatically upon failover.

Recovery Objectives
Recovery Time Objective (RTO): < 10 minutes (Time to update DNS and scale secondary ASG).

Recovery Point Objective (RPO): < 1 second (Data loss limited to Aurora cross-region replication lag).