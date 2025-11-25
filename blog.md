# Building an Azure Landing Zone for Windows 365: A Minimalist Hub & Spoke Approach

As Windows 365 continues to simplify the delivery of Cloud PCs, many organizations find themselves asking: "Where do we put these on our network?"

While Windows 365 Enterprise can run on a Microsoft-hosted network, most enterprise deployments require a connection to an on-premises network or existing Azure resources. This is where the concept of an **Azure Landing Zone** comes in.

In this post, we'll explore a streamlined approach to building a Hub and Spoke network architecture specifically designed for Windows 365. While there is no single "official" reference design that fits every scenario, the solution contained within this repository provides a practical, minimal infrastructure foundation that you can build upon.

## What is an Azure Landing Zone?

An Azure Landing Zone is the output of a multi-subscription Azure environment that accounts for scale, security, governance, networking, and identity. Think of it as the foundation of a house - before you move in your furniture (workloads like Windows 365), you need a solid concrete slab with plumbing and electricity already in place.

For Windows 365, a landing zone ensures:
- **Security**: Centralized firewall and traffic inspection.
- **Connectivity**: Shared paths to on-premises resources or other Azure services.
- **Management**: Unified logging, DNS resolution, and identity services.

## The Hub & Spoke Architecture

This repository implements a classic **Hub and Spoke** topology, which is the industry standard for scalable Azure networking.

### 1. The Hub (`1_Hub`)
The "Hub" is the center of your network. It acts as a connection point for all your other networks (spokes). In our minimal design, the Hub is designed to be cost-effective while still providing essential shared services.

**Technical Nuances:**
- **Minimal Footprint**: We avoid deploying expensive components like VPN Gateways or ExpressRoute circuits by default, keeping the initial cost low.
- **Optional Firewall**: The design includes an optional Azure Firewall (Basic tier) for organizations that need traffic inspection without the high cost of Premium.
- **Shared Services**: It handles "boring but critical" services like Private DNS zones (for private endpoints) and a Log Analytics Workspace for centralized monitoring.

**The Scripts:**
The `1_Hub/deploy.ps1` script orchestrates the deployment of the Hub. It includes flags for validation (`-Validate`) and "what-if" analysis (`-WhatIf`), ensuring you can preview changes before they happen.

### 2. The Windows 365 Spoke (`2_Spoke`)
The "Spoke" is where your actual workloads live. In this case, it's where your Windows 365 Cloud PCs will reside. This isolation ensures that if one workload has an issue, it doesn't bring down the entire network.

**Technical Nuances:**
- **Windows 365 Optimization**: The spoke comes with pre-configured Network Security Groups (NSGs) that already include the necessary rules for Windows 365 traffic (like allowing outbound HTTPS to Microsoft services).
- **Multi-Student Logic**: A unique feature of this repository is its ability to handle multiple "students" or environments. By simply passing a `-StudentNumber` parameter, the script automatically calculates unique non-overlapping IP ranges (e.g., Student 1 gets `192.168.1.0/24`, Student 2 gets `192.168.2.0/24`).
- **Subnet Segmentation**: It automatically carves up the network into dedicated subnets for Cloud PCs, Management, and optional Azure Virtual Desktop (AVD) pools.

**The Scripts:**
The `2_Spoke/deploy.ps1` script is the workhorse here. It handles the complex math of IP allocation for you. It also supports an optional `-hubVnetId` parameter, which automatically configures the VNet peering back to the Hub, stitching the two networks together.

## Detailed Deployment Instructions

Below is the space where we will add detailed, step-by-step instructions on how to use these scripts in your specific environment.

<!-- 
    TODO: Add detailed screenshots and environment-specific configuration steps here.
    include:
    1. Prerequisites (PowerShell modules, Azure permissions).
    2. Step-by-step guide for running the Hub deployment.
    3. Step-by-step guide for running the Spoke deployment.
    4. Verification steps.
-->

[Space reserved for detailed instructions]

---

By using this modular approach, you can start small with a single Hub and Spoke, and easily scale out to dozens of spokes as your Windows 365 deployment grows, all while maintaining a secure and manageable foundation.
