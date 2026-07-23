# Detalied breakdown of each test phrases that has been conducted during the test period.


#  Phase 1 Security Test Report

**Date Performed:** Thu Jul 23 2026
**VPC ID:** `vpc-01bfe876108cc219b`

---

##  Security Test Results

| Test Case | Target | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Public Ingress to DB** | `10.0.21.10:3306` | Connection Timeout / Refused | Air-gapped & unreachable from internet | **PASS** |
| **Bastion SSH Scope** | `3.91.209.98:22` | Restricted to `143.179.136.227/32` | Allowed ONLY from `143.179.136.227/32` | **PASS** |
| **Data Tier Ingress Scope** | `proj1-data-tier-sg` | Allowed ONLY from `app-tier-sg` & `bastion-sg` | Chained strictly to SG IDs: `sg-0d7c27a50e69b5f9e`, `sg-052f149f8658f9922` | **PASS** |

---

##  Verified Security Group Ingress Configuration

### Bastion Host Ingress Rules (`sg-052f149f8658f9922`)
|         DescribeSecurityGroupRules       |
+------+------------+----------------------+
| Port | Protocol   |     SourceCidr       |
+------+------------+----------------------+
|  22  |  tcp       |  143.179.136.227/32  |
+------+------------+----------------------+


### Data Tier Ingress Rules (`sg-0fa3145b2e6343ca8`)
|          DescribeSecurityGroupRules        |
+------+------------+------------------------+
| Port | Protocol   |      SourceGroup       |
+------+------------+------------------------+
| 3306 |  tcp       |  sg-0d7c27a50e69b5f9e  |
| 5432 |  tcp       |  sg-0d7c27a50e69b5f9e  |
|  22  |  tcp       |  sg-052f149f8658f9922  |
+------+------------+------------------------+

#  Phase 2 End-to-End Test Report

**Date Performed:** Thu Jul 23 15:06:04 CEST 2026  
**ALB Public Endpoint:** `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com`  

---

##  Target Group Health Check
* **Path:** `/health`
* **HTTP Status Code:** `200 OK`

---

##  Load Balancing Verification Across Private App Instances

| Request | Endpoint | Status | Responding Instance ID | Availability Zone |
| :--- | :--- | :--- | :--- | :--- |
| Request 1 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-01a70ae25d8f2fb7f` | `us-east-1b` |
| Request 2 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-0f8d70c6a612e5ea0` | `us-east-1a` |
| Request 3 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-0f8d70c6a612e5ea0` | `us-east-1a` |
| Request 4 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-01b253d1783f83220` | `us-east-1a` |
| Request 5 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-01b253d1783f83220` | `us-east-1a` |
| Request 6 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-01a70ae25d8f2fb7f` | `us-east-1b` |

---

##  Test Verdict
* **Result:** **PASSED**
* **Verification Summary:** The Application Load Balancer successfully distributed HTTP requests across multiple private EC2 instances spanning both `us-east-1a` and `us-east-1b`.

#  Traffic Flow & Network Routing Test Report

**Date Performed:** Thu Jul 23 15:06:04 CEST 2026

---

##  Verified Traffic Paths

1. **Ingress Path (Client ➔ App):**
   ```text
   [ Public Client ] ──(HTTP:80)──> [ Internet Gateway ] ──> [ ALB (Public Subnets) ] ──> [ App Server (Private Subnets) ]
   ```
   * **Status:** Verified via Application Load Balancer endpoint `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com`.

2. **Database Ingress Path (App ➔ DB):**
   ```text
   [ App Instance (10.0.11.x / 10.0.12.x) ] ──(TCP:3306)──> [ DB Host (10.0.21.10) ]
   ```
   * **Status:** Verified via application rendering "Database Status: Connected".

3. **Outbound Internet Path (App ➔ Internet):**
   ```text
   [ App Instance (Private Subnet) ] ──> [ NAT Gateway (Public Subnet) ] ──> [ IGW ] ──> [ Internet ]
   ```
   * **Status:** Verified via Node.js setup executing system package updates during user-data bootstrap.
