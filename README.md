# OrbitLab Backplane DNS LXC

This repository contains the configuration, service definitions, and deployment scripts for the OrbitLab Backplane DNS LXC. This LXC is deployed on the OrbitLab backplane network to provide DNS routing for OrbitLab Sectors (virtual networks). Its primary function is to ensure reliable DNS resolution for compute instances within Sectors, even when Sector CIDRs overlap with the external LAN (e.g., Proxmox vmbr0), thereby preventing IP-based DNS resolution failures.

The Backplane DNS LXC acts as the authoritative and recursive resolver for all Sector DNS LXCs. Each Sector DNS LXC is configured to use the Backplane DNS as its upstream resolver and nameserver. In turn, compute instances within a Sector are configured to use their respective Sector DNS LXC as their resolver. This creates a robust DNS resolution chain:

Compute Instance → Sector DNS LXC → Backplane DNS LXC → Default Resolver (user's network)

- **Purpose:** Provides DNS routing for OrbitLab Sectors, preventing resolution failures due to CIDR overlap with external networks.
- **Architecture:** CoreDNS-based, deployed as an LXC on the backplane, managed by systemd. All configuration and operational scripts are included for reproducible deployment.
- **DNS Chain:** Compute Instance → Sector DNS LXC → Backplane DNS LXC → Default Resolver
- **Security:** Follows best practices for DNS and container security, with minimal privileges and clear separation of configuration and runtime data.
