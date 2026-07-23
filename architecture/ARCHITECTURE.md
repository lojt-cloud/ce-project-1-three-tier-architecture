===================================================
3-TIER ARCHITECTURE DEPLOYMENT SUMMARY
===================================================
VPC ID: $VPC_ID

TIER 1 (Presentation):
- ALB Name: app-alb
- ALB DNS: $ALB_DNS
- Target Group: app-target-group
- Security Group: alb-sg (Inbound 80 from 0.0.0.0/0)

TIER 2 (Application):
- Security Group: app-tier-sg (Inbound 80 from alb-sg)
- App Servers: app-server-1a, app-server-1b
- Private Subnets: 10.0.11.0/24 (AZ-a), 10.0.12.0/24 (AZ-b)

TIER 3 (Data):
- Security Group: db-tier-sg (Inbound 3306 & ICMP from app-tier-sg)
- Database Server: db-server-1a (10.0.21.10)
- Isolated Subnet: 10.0.21.0/24 (AZ-a)
===================================================