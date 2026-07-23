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

