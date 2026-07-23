# 📋 3-Tier Architecture Test Plan

## 1. Objectives
Verify the deployment, network security boundaries, traffic routing, high availability, and auto-scaling resilience of the 3-tier AWS infrastructure.

## 2. Scope & Test Phases

- **Phase 1: Security & Network Isolation** — 
Verify air-gapped database subnet, security group chaining, and bastion host ingress locks.

- **Phase 2: Traffic Flow & Routing** — 
Confirm end-to-end HTTP request handling from Client -> ALB -> App Tier -> Database Tier.

- **Phase 3: High Availability & Failover** — 
Validate multi-AZ deployment, ALB target health monitoring, and Auto Scaling Group resilience.

## 3. Success Criteria
- Direct external access to the data tier must be blocked (Connection Refused/Timeout).
- The ALB must successfully load-balance requests across multiple private availability zones.
- Terminated application nodes must be automatically replaced by the Auto Scaling Group.