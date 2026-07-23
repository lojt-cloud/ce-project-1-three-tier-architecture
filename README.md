# AWS 3-Tier Cloud Architecture Deployment

A production-oriented, multi-AZ, highly available 3-tier architecture deployed on AWS, built as the Week 3 capstone project for the Cloud Engineering Bootcamp. The system demonstrates strict network isolation, defense-in-depth security group chaining, automated horizontal scaling, and centralized observability.

**Author:** [Balint Lojt]
**Project Type:** Individual
**Repository:** `ce-project-1-three-tier-architecture`

---

## Overview

This project extends a working 3-tier skeleton (VPC, subnet segmentation, ALB, tier isolation) into a more complete, production-leaning deployment. On top of the required architecture, the following enhancements were implemented:

- **Auto Scaling Group** for the application tier, scaling on CPU utilization instead of a fixed instance count
- **CloudWatch alarms and dashboard** covering ALB, target group, and EC2-level metrics
- **Bastion host** for controlled SSH access into private/isolated subnets that have no direct internet route

These were chosen over other "Should Have" options (RDS Multi-AZ, HTTPS/ACM, ElastiCache) because they directly reinforce the core learning goals of this project — high availability, security isolation, and operational visibility — without requiring infrastructure (a domain name, a managed cache layer) outside the scope of a lab environment.

---

## Architecture

```text
[ Internet Clients ]
        │
        ▼ (Port 80)
┌──────────────────────────────────────────────────────────────────────┐
│ TIER 1: PRESENTATION (Public Subnets — 10.0.1.0/24, 10.0.2.0/24)     │
│                    Application Load Balancer                         │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ (Port 80, Target Group)
┌──────────────────────────────────▼───────────────────────────────────┐
│ TIER 2: APPLICATION (Private Subnets — 10.0.11.0/24, 10.0.12.0/24)   │
│         Auto Scaling Group (min 2 / desired 2 / max 6)               │
│         App Servers (Node.js) — scale on CPUUtilization              │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ (Port 3306, internal only)
┌──────────────────────────────────▼───────────────────────────────────┐
│ TIER 3: DATA (Isolated Subnets — 10.0.21.0/24, 10.0.22.0/24)         │
│                   Database Host (10.0.21.10)                         │
│                   No route to/from the internet                      │
└────────────────────────────────────────────────────────────────────────┘

              ┌───────────────────────────────┐
              │  Bastion Host (Public Subnet) │
              │  SSH access only, from a      │
              │  single trusted IP            │
              └───────────────────────────────┘
                  │ SSH (22) - chained SG
                  ▼ reaches App tier and Data tier
```

Full breakdown of components, rationale, and trade-offs: [`ARCHITECTURE.md`](./architecture/ARCHITECTURE.md)
Network design and routing strategy: [`NETWORK-DESIGN.md`](./architecture/NETWORK-DESIGN.md)
Security group design and isolation model: [`SECURITY.md`](./architecture/SECURITY.md)

---

## Why 3-Tier Architecture

Separating presentation, application, and data into distinct tiers with their own subnets and security boundaries:

- **Limits blast radius** — a compromised app server cannot directly reach the database without also compromising the app-tier security group chain
- **Enables independent scaling** — the application tier scales horizontally via ASG without any change to the load balancer or database
- **Matches least-privilege networking** — each tier can only be reached by the tier immediately above it, never skipped or reached directly from the internet
- **Mirrors real production patterns** — this structure is the default starting point for most AWS reference architectures, and generalizes to serverless and containerized designs later on

Full reflection on trade-offs vs. a monolithic design: see the Reflection Questions section in [`ARCHITECTURE.md`](./architecture/ARCHITECTURE.md).

---

## Security Considerations

Security groups are **chained by SG-ID reference**, not open CIDR ranges, at every internal hop:

| Security Group | Inbound Source | Purpose |
|---|---|---|
| `alb-sg` | `0.0.0.0/0` on 80/443 | Only tier reachable from the internet |
| `app-tier-sg` | `alb-sg` only | App servers unreachable except via ALB |
| `data-tier-sg` | `app-tier-sg` only | Database unreachable except from app tier |
| `bastion-sg` | Trusted IP only, port 22 | Single controlled management entry point |

The database subnets carry **no default route** (`0.0.0.0/0`) at all — they cannot reach the internet and cannot be reached from it, regardless of security group configuration. This is enforced at the routing layer, not just the security group layer, which is intentional defense-in-depth.

The bastion host extends this same chaining pattern to management traffic: `bastion-sg → app-tier-sg` and `bastion-sg → data-tier-sg`, mirroring the existing `alb-sg → app-tier-sg → data-tier-sg` application traffic chain. No tier has more than one path in.

Full detail: [`SECURITY.md`](./architecture/SECURITY.md)

---

## Traffic Flow

1. Client request hits the ALB DNS name over HTTP (port 80)
2. ALB forwards to a healthy target in the app-tier Auto Scaling Group, alternating across both Availability Zones
3. App server queries the database tier over port 3306 (internal-only route)
4. Response returns via the same path

For out-of-band access (troubleshooting, DB corrections, log inspection):

1. Operator SSHes into the bastion host from a pre-authorized IP
2. From the bastion, SSH forwards (via agent forwarding — private key never touches the bastion) into the app or data tier as needed

---

## Deployment / Replication

> Full step-by-step commands live in `config/` (resource IDs and exact CLI calls used for this deployment) and reference the build order below.

This project was built in dependency order — network foundation before routing, routing before security groups, security groups before compute, compute bottom-up before the load balancer:

1. **Network foundation** — VPC, all 6 subnets, Internet Gateway, NAT Gateway
2. **Routing** — public route table (→ IGW), private route table (→ NAT), isolated route table (local only), subnet associations
3. **Security groups** — `alb-sg` → `app-tier-sg` → `data-tier-sg` → `bastion-sg`, created in that order since each later group references an earlier one
4. **Data tier** — database host deployed first so its static IP is known before app tier is configured
5. **Application tier** — Launch Template + Auto Scaling Group, targeting the known DB endpoint
6. **Presentation tier** — target group, register ASG with target group, ALB, listener
7. **Bastion host** — deployed last since it depends only on the VPC and existing SG chain, not on tier readiness
8. **Validation** — see Testing below
9. **Observability** — CloudWatch alarms and dashboard, wired to existing ALB/target group/ASG resources
10. **Documentation** — finalized from notes captured throughout the build

Exact resource identifiers (VPC ID, subnet IDs, security group IDs, ARNs) are recorded in `config/` for reference and reproducibility.

---

## Testing

Testing follows the same layered order as the build, so a failure at any step isolates to a specific layer rather than requiring a full-stack investigation:

| Test | What It Verifies | Details |
|---|---|---|
| Network reachability | App tier can reach data tier over 3306 | [`tests/traffic-flow-test.md`](./tests/traffic-flow-test.md) |
| Security isolation (negative tests) | Internet cannot reach app or data tier directly | [`tests/security-test.md`](./tests/security-test.md) |
| End-to-end via ALB | `/`, `/health`, `/api/stats` all return expected responses through the ALB DNS | [`tests/end-to-end-test.md`](./tests/end-to-end-test.md) |
| Load distribution | Requests alternate across instances/AZs | [`tests/traffic-flow-test.md`](./tests/traffic-flow-test.md) |
| Auto Scaling behavior | ASG launches/terminates instances correctly under CPU load, new instances register with target group automatically | [`tests/autoscaling-test.md`](./tests/autoscaling-test.md) |
| Bastion access | Bastion reachable only from trusted IP; can reach app and data tier; cannot be reached from elsewhere | [`tests/bastion-access-test.md`](./tests/bastion-access-test.md) |

---

## Monitoring

CloudWatch alarms cover:

- ALB `UnHealthyHostCount`
- ALB `HTTPCode_Target_5XX_Count`
- Target group `TargetResponseTime`
- EC2 `CPUUtilization` (also drives the ASG scaling policy)

A CloudWatch dashboard aggregates these into a single view. Details and screenshots: `config/` and `presentation/screenshots/`.

---

## Cost

Itemized monthly cost breakdown and optimization strategies: [`COSTS.md`](./COSTS.md)

---

## Improvements & Next Steps

Short-term and long-term improvements, including the case for migrating the bastion pattern to SSM Session Manager (removing inbound port 22 entirely) and a multi-region design proposal: [`IMPROVEMENTS.md`](./IMPROVEMENTS.md)

---

## Repository Structure

```text
.
├── README.md
├── ARCHITECTURE.md
├── SECURITY.md
├── COSTS.md
├── IMPROVEMENTS.md
├── architecture/
│   ├── ARCHITECTURE.md
│   ├── NETWORK-DESIGN.md
│   ├── SECURITY.md
│   └── architecture-diagram.png
├── config/
│   ├── vpc-subnets.txt
│   ├── security-groups.txt
│   ├── load-balancer.txt
│   ├── instances.txt
│   ├── autoscaling.txt
│   └── bastion-access.md
├── app/
│   ├── server.js
│   ├── userdata.sh
│   └── db-sim.sh
├── tests/
│   ├── traffic-flow-test.md
│   ├── security-test.md
│   ├── end-to-end-test.md
│   ├── autoscaling-test.md
│   └── bastion-access-test.md
└── presentation/
    ├── slides.pdf
    ├── demo-script.md
    └── screenshots/
```

---

## Team

Individual project — [Balint Lojt]