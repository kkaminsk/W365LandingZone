# Windows 365 Landing Zone - Hub & Spoke Network Deployment

This repository provides Infrastructure-as-Code (IaC) solutions for deploying a hub-and-spoke network architecture designed for **Windows 365** Cloud PC deployments with a basic **Azure Landing Zone** foundation.

## Overview

The repository contains two complementary solutions that work together to create a complete networking infrastructure:

1. **Hub Network (`1_Hub/`)** - Central connectivity and shared services
2. **Spoke Network (`2_Spoke/`)** - Windows 365 Cloud PC workload networks

These solutions use **Azure Bicep** templates and **PowerShell** deployment scripts to automate the provisioning of enterprise-ready networks for Windows 365.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hub VNet (10.10.0.0/20)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Management   │  │   Private    │  │  Azure Firewall      │  │
│  │   Subnet     │  │  Endpoints   │  │  (Optional)          │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                 │
│  Shared Services: Firewall, Private DNS, Log Analytics          │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ VNet Peering
             │
     ┌───────┴────────┬──────────────────┐
     │                │                  │
                                       
┌─────────┐      ┌─────────┐       ┌─────────┐
│ Spoke 1 │      │ Spoke 2 │  ...  │ Spoke N │
│ Student │      │ Student │       │ Student │
│    1    │      │    2    │       │   40    │
└─────────┘      └─────────┘       └─────────┘
192.168.1.0/24   192.168.2.0/24    192.168.40.0/24

Each Spoke VNet contains:
├── Cloud PC Subnet (Windows 365)
├── Management Subnet
└── AVD Subnet (Optional)
```

## Repository Structure

```
W365LandingZone/
├── 1_Hub/                          # Hub network solution
│   ├── deploy.ps1                  # Hub deployment script
│   ├── verify.ps1                  # Post-deployment verification
│   ├── QUICKSTART.md               # Quick start guide
│   ├── infra/                      # Bicep templates
│   │   ├── modules/                # Reusable Bicep modules
│   │   └── envs/prod/              # Production environment config
│   └── scripts/                    # Helper scripts (RBAC, users)
│
└── 2_Spoke/                        # Windows 365 spoke solution
    ├── deploy.ps1                  # Spoke deployment script
    ├── QUICKSTART.md               # Quick start guide
    ├── README.md                   # Detailed spoke documentation
    ├── Setup-MinimumPermissions.ps1 # Security configuration script
    ├── Set-W365Permissions.ps1     # Windows 365 permission setup
    ├── infra/                      # Bicep templates
    │   ├── modules/                # Reusable Bicep modules
    │   └── envs/prod/              # Production environment config
    └── [Documentation files]       # Architecture, IP addressing, etc.
```

## Quick Start

### Option 1: Deploy Complete Hub-Spoke Solution

**Step 1: Deploy Hub Network**
```powershell
cd 1_Hub
.\deploy.ps1
```

**Step 2: Deploy Windows 365 Spoke Network**
```powershell
cd ..\2_Spoke
.\deploy.ps1 -StudentNumber 1
```

**Step 3: Configure VNet Peering** (See detailed instructions below)

### Option 2: Deploy Spoke Only (Standalone)

If you already have existing network infrastructure or want a standalone Windows 365 network:

```powershell
cd 2_Spoke
.\deploy.ps1 -StudentNumber 1
```

## Solution 1: Hub Network (`1_Hub/`)

### Purpose
Provides centralized connectivity, security, and shared services for a hub-and-spoke network topology following Azure Landing Zone design principles.

### What Gets Deployed

#### Resource Groups
- `rg-hub-net` - Network resources
- `rg-hub-ops` - Operations and monitoring resources

#### Networking (10.10.0.0/20)
- **Virtual Network** with subnets:
  - Management Subnet: 10.10.0.0/24
  - Private Endpoints Subnet: 10.10.1.0/24
  - Azure Firewall Subnet: 10.10.2.0/26 (optional)
  - Gateway Subnet: 10.10.3.0/27 (optional)
- **Network Security Groups** (2)
- **Azure Firewall** (Basic tier) - optional
- **Public IP** for Firewall

#### Shared Services
- **Private DNS Zones**:
  - privatelink.azurewebsites.net
  - privatelink.blob.core.windows.net
  - Virtual Network Links
- **Log Analytics Workspace** for centralized monitoring
- **Diagnostic Settings** for subscription activity logs

#### Governance
- **Azure Policy** assignment (Allowed Locations)
- **Azure Budget** ($200/month with alerts) - optional
- **RBAC Assignments** (if group IDs provided)

### Deployment

```powershell
# Navigate to hub folder
cd 1_Hub

# Validate Bicep templates
.\deploy.ps1 -Validate

# Preview changes (what-if)
.\deploy.ps1 -WhatIf

# Deploy hub network
.\deploy.ps1

# Verify deployment
.\verify.ps1
```

### Configuration

Edit `1_Hub/infra/envs/prod/parameters.prod.json`:
```json
{
  "location": "canada-central",
  "env": "prod",
  "allowedLocations": ["canadacentral", "canadaeast"],
  "networkAdminsGroupObjectId": "<your-aad-group-id>",
  "opsGroupObjectId": "<your-aad-group-id>"
}
```

### Documentation
- **[QUICKSTART.md](1_Hub/QUICKSTART.md)** - Quick deployment guide
- **[Deployps1-Readme.md](1_Hub/Deployps1-Readme.md)** - Detailed deployment documentation

**Estimated Deployment Time:** 5-10 minutes

## Solution 2: Windows 365 Spoke Network (`2_Spoke/`)

### Purpose
Provides dedicated network infrastructure for Windows 365 Cloud PC deployments with multi-student support (up to 40 students/environments).

### What Gets Deployed

#### Resource Group
- `rg-w365-spoke-student{N}-prod` (where N = student number 1-40)

#### Networking (192.168.{N}.0/24)
- **Virtual Network** with automatic IP addressing based on student number:
  - **Cloud PC Subnet**: 192.168.{N}.0/26 (62 usable IPs for Windows 365)
  - **Management Subnet**: 192.168.{N}.64/26 (62 usable IPs)
  - **AVD Subnet**: 192.168.{N}.128/26 (optional, disabled by default)
  - **Reserved**: 192.168.{N}.192/26 (future expansion)

#### Security
- **Network Security Groups** (3) pre-configured for Windows 365:
  - Cloud PC NSG (RDP allowed from VNet, HTTPS outbound)
  - Management NSG
  - AVD NSG (if enabled)
- **Service Endpoints**: Storage and KeyVault

#### Optional Features
- **VNet Peering** to hub network (when `hubVnetId` is configured)

### Deployment

```powershell
# Navigate to spoke folder
cd 2_Spoke

# Deploy for Student 1 (uses 192.168.1.0/24)
.\deploy.ps1 -StudentNumber 1

# Deploy for Student 5 (uses 192.168.5.0/24)
.\deploy.ps1 -StudentNumber 5

# Validate before deploying
.\deploy.ps1 -Validate -StudentNumber 10
```

### IP Address Allocation

Each student receives a unique `/24` network:

| Student | VNet CIDR | Cloud PC Subnet | Management Subnet | AVD Subnet |
|---------|-----------|-----------------|-------------------|------------|
| Student 1 | 192.168.1.0/24 | 192.168.1.0/26 | 192.168.1.64/26 | 192.168.1.128/26 |
| Student 5 | 192.168.5.0/24 | 192.168.5.0/26 | 192.168.5.64/26 | 192.168.5.128/26 |
| Student N | 192.168.{N}.0/24 | 192.168.{N}.0/26 | 192.168.{N}.64/26 | 192.168.{N}.128/26 |

### Configuration

Edit `2_Spoke/infra/envs/prod/parameters.prod.json`:
```json
{
  "location": { "value": "southcentralus" },
  "studentNumber": { "value": 1 },
  "enableAvdSubnet": { "value": false },
  "hubVnetId": { "value": "" }
}
```

### Security & Permissions

For enterprise deployments with minimum privilege requirements, use the provided security setup scripts in the `2_Spoke/` directory.

### Documentation
- **[QUICKSTART.md](2_Spoke/QUICKSTART.md)** - Quick deployment guide
- **[README.md](2_Spoke/README.md)** - Comprehensive spoke documentation
- **[IP-ADDRESSING.md](2_Spoke/IP-ADDRESSING.md)** - Multi-student IP allocation details
- **[ARCHITECTURE-DIAGRAM.md](2_Spoke/ARCHITECTURE-DIAGRAM.md)** - Network topology diagrams
- **[HUB-VS-SPOKE.md](2_Spoke/HUB-VS-SPOKE.md)** - Comparison and integration guide
- **[PERMISSIONS-AND-RESTRICTIONS.md](2_Spoke/PERMISSIONS-AND-RESTRICTIONS.md)** - Security configuration

**Estimated Deployment Time:** 3-5 minutes per spoke

## Connecting Hub and Spoke

### Step 1: Deploy Hub Network
```powershell
cd 1_Hub
./deploy.ps1
```
Note the Hub VNet Resource ID from the deployment output.

### Step 2: Deploy Spoke with Hub Integration

Update `2_Spoke/infra/envs/prod/parameters.prod.json`:
```json
{
  "hubVnetId": { 
    "value": "/subscriptions/{sub-id}/resourceGroups/rg-hub-net/providers/Microsoft.Network/virtualNetworks/vnet-hub"
  }
}
```

Deploy the spoke:
```powershell
cd 2_Spoke
./deploy.ps1 -StudentNumber 1
```

### Step 3: Create Reverse Peering (Hub to Spoke)

In the hub network, create peering back to the spoke:

```powershell
New-AzVirtualNetworkPeering `
  -Name "peer-to-w365-spoke-student1" `
  -VirtualNetwork (Get-AzVirtualNetwork -Name "vnet-hub" -ResourceGroupName "rg-hub-net") `
  -RemoteVirtualNetworkId "/subscriptions/{sub-id}/resourceGroups/rg-w365-spoke-student1-prod/providers/Microsoft.Network/virtualNetworks/vnet-w365-spoke-student1-prod" `
  -AllowForwardedTraffic `
  -AllowGatewayTransit
```

## Prerequisites

### Required Software
- **Azure PowerShell** (Az module)
- **Bicep CLI** - `winget install -e --id Microsoft.Bicep` 
- **PowerShell 5.1+** or **PowerShell 7+**

### Azure Requirements
- **Azure Subscription** with appropriate permissions
- **Permissions** (Hub): Owner or Contributor at subscription level
- **Permissions** (Spoke): Contributor or Network Contributor at subscription level

### Quick Setup
```powershell
# Install Bicep CLI
winget install -e --id Microsoft.Bicep

# Verify installation
bicep --version

# Login to Azure
Connect-AzAccount

# Verify subscription
Get-AzContext
```

## Use Cases

### Scenario 1: Enterprise Hub-Spoke with Windows 365
Deploy centralized hub infrastructure with multiple Windows 365 spoke networks for different teams/students.

### Scenario 2: Standalone Windows 365 Network
Quick Windows 365 deployment without hub infrastructure.

### Scenario 3: Training/Lab Environment
Support multiple students (up to 40) with isolated networks and automated IP addressing.

## Security Features

### Hub Network
- Azure Firewall for centralized traffic inspection (optional)
- Private DNS zones for Azure services
- Centralized Log Analytics workspace
- Azure Policy enforcement
- RBAC assignments for governance

### Spoke Networks
- Pre-configured NSG rules for Windows 365
- RDP restricted to VirtualNetwork scope
- HTTPS outbound for Windows 365 service connectivity
- Service endpoints for Storage and KeyVault
- Subnet segmentation (Cloud PCs, Management, AVD)
- Optional custom RBAC roles with minimum privileges

## Best Practices

1. **Deploy Hub First** - Always deploy the hub network before spoke networks
2. **Use Validation** - Run `.\deploy.ps1 -Validate` before actual deployment
3. **Document IP Ranges** - Maintain a spreadsheet of allocated IP ranges
4. **Version Control** - Store all configuration files in Git
5. **Test in Dev** - Deploy to dev/test environments first

## Next Steps

1. Review architecture and IP addressing scheme
2. Deploy hub network (if using hub-spoke topology)
3. Deploy spoke network(s) for Windows 365
4. Configure VNet peering (if using hub-spoke)
5. Set up Windows 365 provisioning policies
6. Deploy Cloud PCs to spoke subnet

## Additional Resources

- [Azure Landing Zones](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Windows 365 Documentation](https://learn.microsoft.com/en-us/windows-365/)
- [Hub-Spoke Network Topology](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

## License

See [LICENSE](LICENSE) file for details.

---

**Ready to deploy?** Start with the [Hub QUICKSTART](1_Hub/QUICKSTART.md) or [Spoke QUICKSTART](2_Spoke/QUICKSTART.md)! 
