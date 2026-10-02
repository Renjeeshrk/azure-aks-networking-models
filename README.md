# Azure AKS Networking Models with Terraform

This repository demonstrates three Azure Kubernetes Service (AKS) networking
models using Terraform:

1. Azure CNI Overlay
2. Azure CNI Node Subnet
3. Azure CNI Pod Subnet

The purpose of this repository is to demonstrate how the AKS networking model
changes the IP addressing and network architecture of an AKS cluster.

The infrastructure uses a common Azure Hub-Spoke architecture so that the
three networking models can be deployed and compared independently.

---

## Architecture

The high-level architecture consists of:

- Azure Hub VNet
- Azure Spoke VNets
- VNet Peering
- Azure Application Gateway
- Azure Firewall
- AKS cluster
- AKS node subnet
- AKS pod networking depending on the selected CNI model

High-level architecture:

```text
                         Internet
                            |
                            |
                   Public IP / HTTPS
                            |
                            v
                 +----------------------+
                 | Application Gateway  |
                 |      / WAF            |
                 +----------+-----------+

                            |
                     VNet Peering
                            |
              +-------------+-------------+
              |                           |
              v                           v
        Spoke 1                      Spoke 2
       Compute                       AKS
        VNet                         VNet
              |                           |
        Application VMs              AKS Cluster
        / Services                  Nodes + Pods