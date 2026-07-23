# 🧪 Phase 2 End-to-End Test Report

**Date Performed:** Thu Jul 23 15:06:04 CEST 2026  
**ALB Public Endpoint:** `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com`  

---

## 📋 Target Group Health Check
* **Path:** `/health`
* **HTTP Status Code:** `200 OK`

---

## 🔄 Load Balancing Verification Across Private App Instances

| Request | Endpoint | Status | Responding Instance ID | Availability Zone |
| :--- | :--- | :--- | :--- | :--- |
| Request 1 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-01a70ae25d8f2fb7f` | `us-east-1b` |
| Request 2 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-0f8d70c6a612e5ea0` | `us-east-1a` |
| Request 3 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-0f8d70c6a612e5ea0` | `us-east-1a` |
| Request 4 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-01b253d1783f83220` | `us-east-1a` |
| Request 5 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-01b253d1783f83220` | `us-east-1a` |
| Request 6 | `http://proj1-alb-336927573.us-east-1.elb.amazonaws.com` | 200 OK | `i-01a70ae25d8f2fb7f` | `us-east-1b` |

---

## 🏆 Test Verdict
* **Result:** **PASSED**
* **Verification Summary:** The Application Load Balancer successfully distributed HTTP requests across multiple private EC2 instances spanning both `us-east-1a` and `us-east-1b`.
