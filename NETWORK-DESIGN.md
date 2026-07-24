# Network Design — VPC, Subnets, and Routing

This document details the network topology and routing strategy for the
3-Tier Architecture (`vpc-01bfe876108cc219b`), built across two Availability
Zones for fault tolerance and tier isolation.

---

## VPC and Subnet Allocation

**VPC CIDR:** `10.0.0.0/16`
**Region:** `us-east-1`, spanning `us-east-1a` and `us-east-1b`

| Subnet | CIDR | AZ | Type | Route Target |
|---|---|---|---|---|
| public-subnet-1a | `10.0.1.0/24` | us-east-1a | Public | Internet Gateway |
| public-subnet-1b | `10.0.2.0/24` | us-east-1b | Public | Internet Gateway |
| app-subnet-1a | `10.0.11.0/24` | us-east-1a | Private | NAT Gateway (in 1a) |
| app-subnet-1b | `10.0.12.0/24` | us-east-1b | Private | NAT Gateway (in 1a — cross-AZ) |
| data-subnet-1a | `10.0.21.0/24` | us-east-1a | Isolated | Local VPC only |
| data-subnet-1b | `10.0.22.0/24` | us-east-1b | Isolated | Local VPC only |

CIDR blocks are deliberately numbered in tens (`.1`/`.2` → `.11`/`.12` →
`.21`/`.22`) to make tier boundaries visually obvious and leave room for
additional subnets per tier without renumbering.

---

## Route Tables

Three route tables exist, each **shared across both AZs** rather than
duplicated per subnet — the routing rule is identical for both AZs within a
tier, so one table per tier is sufficient.

| Route Table | Associated Subnets | Routes |
|---|---|---|
| `public-rt` | public-subnet-1a, public-subnet-1b | `10.0.0.0/16 → local`, `0.0.0.0/0 → IGW` |
| `app-rt` | app-subnet-1a, app-subnet-1b | `10.0.0.0/16 → local`, `0.0.0.0/0 → NAT Gateway` |
| `data-rt` | data-subnet-1a, data-subnet-1b | `10.0.0.0/16 → local` — **no default route** |

### Why the data tier has no default route

This is the core security control of the whole architecture, enforced at the
routing layer rather than the security-group layer. Even if every security
group were misconfigured to allow all traffic, instances in the data subnets
still have no path to or from the internet, because none exists in the route
table. This is a stronger guarantee than a security group provides, since it
doesn't depend on any policy being correctly configured — there's simply no
route.

---

## Internet Gateway

One IGW (`igw-0d8218a7dc5a13fbe`), attached to the VPC, providing two-way
routing exclusively for the public subnets. Nothing in the app or data tier
ever references the IGW directly.

---

## NAT Gateway — single instance, documented trade-off

**One NAT Gateway** (`nat-05d4531bfaea569ba`) exists, placed in
`public-subnet-1a`. It provides outbound-only internet access for both app
subnets — including `app-subnet-1b`, whose traffic crosses AZ boundaries to
reach it, since no NAT Gateway exists in `us-east-1b`.

**This is a known, deliberate single point of failure**, not an oversight:
a full Multi-AZ NAT Gateway deployment was scoped out due to the free-tier
account's cost model (NAT Gateways are not free-tier eligible, unlike EC2
t2/t3.micro instances) combined with limited remaining project time. If
`us-east-1a` experiences an outage, `app-subnet-1b`'s instances lose
outbound internet access even though they remain otherwise healthy — this
is the single largest availability gap in the current architecture, and
the first item to address given more time or a production account.

---

## End-to-End Traffic Path

```
[ External Client ]
       │ (HTTP:80)
       ▼
[ Internet Gateway ]
       │
       ▼
[ Application Load Balancer ]  (public-subnet-1a, public-subnet-1b)
       │
       │ (HTTP:80, via Target Group)
       ▼
[ App Servers — Auto Scaling Group ]  (app-subnet-1a, app-subnet-1b)
       │
       │ (TCP:3306, internal only)
       ▼
[ Database Instance ]  (data-subnet-1a — single-AZ, see IMPROVEMENTS.md)
```

Management/troubleshooting traffic follows a separate path entirely, via the
bastion host — see `SECURITY.md` for the full security-group chain.