## Overview
Security in this 3-tier architecture is structured using a **Defense-in-Depth** model. Every layer maintains explicit network, protocol, and credential security barriers, strictly adhering to the **Principle of Least Privilege**.

---

##  Security Group Chaining Architecture

Rather than opening ports to CIDR ranges, Security Groups are **chained directly to one another** by referencing Security Group IDs as ingress sources.