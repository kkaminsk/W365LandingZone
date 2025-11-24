# Windows 365 Spoke Network Infrastructure

This folder contains Bicep infrastructure-as-code for deploying a Windows 365 spoke network to Azure.

## 🚀 Quick Start

```powershell
# Navigate to W365 folder
cd W365

# Deploy for student 1 (uses 192.168.1.0/24)
.\deploy.ps1 -StudentNumber 1

# Deploy for student 5 (uses 192.168.5.0/24)
.\deploy.ps1 -StudentNumber 5

# Validate template before deployment
.\deploy.ps1 -Validate -StudentNumber 10

# Deploy to a specific tenant and subscription (multi-tenant admins)
.\deploy.ps1 -TenantId "<tenant-guid>" -SubscriptionId "<subscription-guid>" -StudentNumber 1
```

> **⚠️ Important**: Always specify `-StudentNumber` (1-40) to ensure unique IP addressing for each student. See [IP-ADDRESSING.md](./IP-ADDRESSING.md) for details.

## 📦 What's Included

- **Resource Group**: `rg-w365-spoke-student{N}-prod` (where {N} = student number)
- **Virtual Network**: `192.168.{N}.0/24` (where {N} = student number 1-40)
  - Cloud PC Subnet: `192.168.{N}.0/26` (62 usable IPs)
  - Management Subnet: `192.168.{N}.64/26` (62 usable IPs)
  - AVD Subnet: `192.168.{N}.128/26` (optional, disabled by default)
- **Network Security Groups**: Pre-configured for Windows 365
- **Service Endpoints**: Storage and KeyVault
- **Hub Peering**: Optional connection to hub network

## 📋 Prerequisites

### Required Permissions

You need **ONE** of these:
- ✅ **Contributor** role at subscription level
- ✅ **Network Contributor** role + resource group write permission
- ✅ **Custom role** (see PERMISSIONS-AND-RESTRICTIONS.md for least-privilege setup)

**📖 For detailed permission requirements and security setup:**
- See **[PERMISSIONS-AND-RESTRICTIONS.md](./PERMISSIONS-AND-RESTRICTIONS.md)** for minimum permissions, restrictions, and automated setup
- Use **[Setup-MinimumPermissions.ps1](./Setup-MinimumPermissions.ps1)** to automate security configuration

### Required Software

- Azure PowerShell (Az module)
- Microsoft Graph PowerShell modules
- Bicep CLI

```powershell
# RECOMMENDED: Install all required modules at once
cd ..
cd InstallStudentModules
.\InstallStudentModules.ps1

# Install Bicep CLI
winget install -e --id Microsoft.Bicep

# Verify Bicep installation
bicep --version
```

## 📖 Documentation

- **[IP-ADDRESSING.md](./IP-ADDRESSING.md)** - **Multi-student IP addressing scheme (IMPORTANT)**
- **[Deployps1-Readme.md](./Deployps1-Readme.md)** - Complete deployment guide with troubleshooting
- **[deploy.ps1](./deploy.ps1)** - PowerShell deployment script

## 🎯 IP Address Allocation (Per Student)

Each student receives a unique `/24` network based on their student number:

**Pattern**: `192.168.X.0/24` where `X` = Student Number (1-40)

**Example for Student 5**:

| Subnet | Range | CIDR | Usable IPs | Purpose |
|--------|-------|------|------------|---------|
| Cloud PC | 192.168.5.0 - 192.168.5.63 | /26 | 62 | Windows 365 Cloud PCs |
| Management | 192.168.5.64 - 192.168.5.127 | /26 | 62 | Management resources |
| AVD | 192.168.5.128 - 192.168.5.191 | /26 | 62 | Azure Virtual Desktop (optional) |
| Reserved | 192.168.5.192 - 192.168.5.255 | - | 64 | Future expansion |

> **📘 See [IP-ADDRESSING.md](./IP-ADDRESSING.md)** for complete details on multi-student deployments, capacity planning, and troubleshooting.

## ⚙️ Configuration

Edit `infra/envs/prod/parameters.prod.json` to customize:

```json
{
  "location": { "value": "southcentralus" },
  "studentNumber": { "value": 1 },
  "enableAvdSubnet": { "value": false },
  "hubVnetId": { "value": "" }
}
```

> **Note**: IP addresses are calculated automatically based on `studentNumber`. You no longer need to specify `vnetAddressSpace`, `cloudPCSubnetPrefix`, etc.

## 🔗 Hub Peering

To connect to hub network, set the hub VNet ID:

```json
{
  "hubVnetId": { 
    "value": "/subscriptions/{sub-id}/resourceGroups/rg-hub-net/providers/Microsoft.Network/virtualNetworks/vnet-hub"
  }
}
```

⚠️ **Note**: You must also create the reverse peering from hub to spoke.

## 🔐 Security Features

- **NSG Rules**: Pre-configured for Windows 365 traffic
- **Service Endpoints**: Storage and KeyVault enabled
- **Subnet Segmentation**: Isolated Cloud PC, management, and AVD subnets
- **RDP Controls**: Limited to VirtualNetwork scope

## 📁 Folder Structure

```
W365/
├── deploy.ps1                    # Deployment script
├── Deployps1-Readme.md           # Full documentation
├── README.md                     # This file
└── infra/
    ├── modules/
    │   ├── rg/                   # Resource group module
    │   └── spoke-network/        # VNet and subnets module
    └── envs/
        └── prod/
            ├── main.bicep        # Main template
            └── parameters.prod.json  # Configuration
```

## 🎓 Next Steps

1. **Deploy the spoke network**: `.\deploy.ps1`
2. **Configure Windows 365**:
   - Set up Azure AD join
   - Create provisioning policy
   - Deploy Cloud PCs to `snet-cloudpc` subnet
3. **Optional: Connect to hub**:
   - Update `hubVnetId` parameter
   - Create reverse peering from hub

## 💡 Tips

- Always run `-Validate` before deploying
- Use `-WhatIf` to preview changes
- Customize NSG rules for your security requirements
- Document your IP address assignments

## 🔐 Security & Minimum Permissions

For enterprise deployments with strict security requirements:

### Automated Security Setup

```powershell
# Run as subscription owner/admin
.\Setup-MinimumPermissions.ps1 `
    -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -AdminEmail "networkadmin@contoso.com" `
    -UseCustomRole `
    -MonthlyBudget 50 `
    -CreateResourceGroup
```

This configures:
- ✅ Least-privilege RBAC role (custom or Network Contributor)
- ✅ Azure Policies (region, IP range, tagging restrictions)
- ✅ Budget alerts ($50/month default)
- ✅ Resource locks (prevent accidental deletion)
- ✅ Scoped permissions (single resource group only)

### Windows 365 Service Permissions

After deploying the network, configure Windows 365 service:

```powershell
# Assign required permissions for Windows 365
.\Set-W365Permissions.ps1

# Verify permissions are correct
.\Check-W365Permissions.ps1
```

### Documentation

- **[PERMISSIONS-AND-RESTRICTIONS.md](./PERMISSIONS-AND-RESTRICTIONS.md)** - Complete security guide
- **[W365-MinimumRole.json](./W365-MinimumRole.json)** - Custom RBAC role definition
- **[Setup-MinimumPermissions.ps1](./Setup-MinimumPermissions.ps1)** - Automated setup script

---

## 📞 Need Help?

See the **[Deployps1-Readme.md](./Deployps1-Readme.md)** for:
- Detailed troubleshooting guide
- Permission requirements
- Common deployment errors
- Configuration examples

---

**Ready to deploy?** Start with `.\deploy.ps1 -Validate` 🚀
