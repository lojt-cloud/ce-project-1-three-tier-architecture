This document details the Network Topology and Routing Strategy for the 3-Tier Enterprise AWS Architecture (`vpc-04ab384385311bf3a`). The VPC is designed across multiple Availability Zones (AZs) to ensure high availability, fault tolerance, and strict tier isolation.

---

##  VPC & Subnet Allocation

* **VPC CIDR:** `10.0.0.0/16`
* **Region:** Multi-AZ deployment (AZ-a & AZ-b)

| Tier / Subnet Name | CIDR Block | Subnet Type | Route / Gateway Target | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Public Subnet 1a** | `10.0.1.0/24` | Public | Internet Gateway (`igw-*`) | Tier 1: ALB Ingress (AZ-a) |
| **Public Subnet 1b** | `10.0.2.0/24` | Public | Internet Gateway (`igw-*`) | Tier 1: ALB Ingress (AZ-b) |
| **App Subnet 1a** | `10.0.11.0/24` | Private | NAT Gateway (`nat-*`) | Tier 2: Application Server (AZ-a) |
| **App Subnet 1b** | `10.0.12.0/24` | Private | NAT Gateway (`nat-*`) | Tier 2: Application Server (AZ-b) |
| **DB Subnet 1a** | `10.0.21.0/24` | Isolated | Local VPC Route Only | Tier 3: Database Instance (AZ-a) |
| **DB Subnet 1b** | `10.0.22.0/24` | Isolated | Local VPC Route Only | Tier 3: Database Instance (AZ-b) |

---

##  Routing & Egress Strategy

### 1. Public Subnets (Presentation Layer)
* **Route Table:** `0.0.0.0/0` routed to the **Internet Gateway (IGW)**.
* Accepts inbound HTTP (Port 80) traffic from external clients on the Application Load Balancer (ALB).

### 2. Private Subnets (Application Layer)
* **Route Table:** `0.0.0.0/0` routed to the **NAT Gateway**.
* **Outbound Internet:** App instances can initiate outbound requests (e.g., `dnf update`, Node.js package downloads) via NAT Gateway without revealing public IPv4 addresses.
* **Inbound Access:** Completely blocked from the internet; reachable **only** via the ALB in public subnets.

### 3. Isolated Subnets (Data Layer)
* **Route Table:** Local VPC CIDR (`10.0.0.0/16`) only. No default route (`0.0.0.0/0`).
* **Zero Egress:** Database instances cannot reach out to the internet, nor can the internet reach them. Communication is constrained strictly to the local VPC.

---

##  End-to-End Traffic Path

```text
[ External Client ] 
       │ (HTTP:80)
       ▼
[ Internet Gateway ]
       │
       ▼
[ Application Load Balancer ] (Public Subnets: 10.0.1.0/24 & 10.0.2.0/24)
       │
       │ (HTTP:80 - Internal Route via Target Group)
       ▼
[ App Servers (Node.js) ] (Private Subnets: 10.0.11.0/24 & 10.0.12.0/24)
       │
       │ (MySQL:3306 - Internal Route)
       ▼
[ Database Instance ] (Isolated Subnet: 10.0.21.0/24)