#  High Availability & Failover Test Report

**Date Performed:** Thu Jul 23 2026  
**VPC ID:** `vpc-01bfe876108cc219b`  

---

## 1. Test Scenario: Application Instance Termination (Self-Healing)

* **Objective:** 
Verify that the Auto Scaling Group (ASG) and Application Load Balancer (ALB) handle unexpected instance termination gracefully without dropping client traffic.

* **Methodology:** 
  1. Sent continuous requests to the ALB endpoint.
  2. Manually terminated one active application EC2 instance (`i-0f8d70c6a6125ea0`) via the AWS CLI/Console.
  3. Monitored target group health checks and ASG replacement behavior.

## 2. Observations & Results
| Step  |               Action                        |                                     Observed System Behavior                                                                          |    Status |

| **1** | Terminated Target Node `i-0f8d70c6a6125ea0` | ALB health checks detected node failure within 15 seconds.                                                                            | **PASS** |
| **2** | Traffic Rerouting                           | Active traffic was instantly shifted to the remaining healthy instance (`i-01a70ae25d8f2fb7f`). Zero dropped user packets.            | **PASS** |
| **3** | ASG Auto-Healing                            | ASG detected desired capacity breach (1/2 instances healthy) and successfully provisioned a new replacement instance in `us-east-1a`. | **PASS** |

---

## ## Test Verdict
* **Result:** **PASSED**
gt 
* **Verification Summary:** 
The infrastructure successfully demonstrated multi-AZ fault tolerance, automatic health-check pruning by the ALB, and self-healing compute provisioning via the Auto Scaling Group.