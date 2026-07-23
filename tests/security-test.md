# 🧪 Phase 1 Security Test Report (Intermediate Sanity Check)

**Date Performed:** Thu Jul 23 11:40:13 CEST 2026
**VPC ID:** `vpc-01bfe876108cc219b`

---

## 🎯 Test Objectives
Verify zero-trust security perimeters for Tier 3 (Database) and Tier 1 (Bastion Host) prior to deploying Tier 2 application servers.

---

## 📋 Test Results Summary

| Test Case | Target | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Test A: Public Ingress to DB** | `10.0.21.10:3306` | Connection Timeout / Failed | PASSED (Air-gapped & unreachable from public internet) | **PASS** |
| **Test B: Bastion SSH Scope** | `3.91.209.98:22` | Restricted to `143.179.136.227/32` | Allowed ONLY from `143.179.136.227/32` | **PASS** |
| **Test C: Data Tier Ingress Scope** | `proj1-data-tier-sg` | Allowed ONLY from `sg-0d7c27a50e69b5f9e` & `sg-052f149f8658f9922` | Chained to SG IDs: `sg-0d7c27a50e69b5f9e`, `sg-052f149f8658f9922` | **PASS** |

---

## 🔐 Raw Security Group Policy Logs

### Bastion Host Ingress Rules (`sg-052f149f8658f9922`)
```
--------------------------------------------
|        DescribeSecurityGroupRules        |
+------+------------+----------------------+
| Port | Protocol   |     SourceCidr       |
+------+------------+----------------------+
|  -1  |  -1        |  0.0.0.0/0           |
|  22  |  tcp       |  143.179.136.227/32  |
+------+------------+----------------------+
```

### Data Tier Ingress Rules (`sg-0fa3145b2e6343ca8`)
```
----------------------------------------------
|         DescribeSecurityGroupRules         |
+------+------------+------------------------+
| Port | Protocol   |      SourceGroup       |
+------+------------+------------------------+
|  3306|  tcp       |  sg-0d7c27a50e69b5f9e  |
|  5432|  tcp       |  sg-0d7c27a50e69b5f9e  |
|  22  |  tcp       |  sg-052f149f8658f9922  |
|  -1  |  -1        |  None                  |
+------+------------+------------------------+
```

---
*Report generated automatically during deployment pipeline.*
