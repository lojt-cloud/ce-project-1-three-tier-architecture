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
