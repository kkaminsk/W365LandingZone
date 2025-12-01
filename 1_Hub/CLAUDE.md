# CLAUDE.md - Hub Landing Zone

## Overview

This folder contains the **Hub Landing Zone** infrastructure for the Windows 365 deployment. It deploys centralized networking, monitoring, and shared services that spoke networks (Windows 365 environments) connect to.

## Folder Structure

```
1_Hub/
├── deploy.ps1                    # Main deployment script
├── verify.ps1                    # Post-deployment validation
├── infra/
│   ├── envs/prod/
│   │   ├── main.bicep            # Orchestration template
│   │   └── parameters.prod.json  # Parameter values
│   ├── modules/                  # Reusable Bicep modules
│   │   ├── rg/                   # Resource groups
│   │   ├── hub-network/          # VNet, subnets, NSGs
│   │   ├── log-analytics/        # Monitoring workspace
│   │   ├── private-dns/          # Private DNS zones
│   │   ├── diagnostics/          # Activity log routing
│   │   ├── policy/               # Azure Policy (optional)
│   │   ├── rbac/                 # Role assignments (optional)
│   │   └── budget/               # Cost alerts (optional)
│   └── scripts/entra/            # Entra ID setup scripts
└── Documentation (*.md files)
```

## Key Commands

```powershell
# Validate template without deploying
.\deploy.ps1 -Validate

# Preview changes (what-if analysis)
.\deploy.ps1 -WhatIf

# Full deployment
.\deploy.ps1

# Post-deployment verification
.\verify.ps1
```

## What Gets Deployed

### Core Resources (Always Deployed)
| Resource | Name | Purpose |
|----------|------|---------|
| Resource Groups | `rg-hub-net`, `rg-hub-ops` | Networking and operations |
| Virtual Network | `vnet-hub` (10.10.0.0/20) | Hub connectivity |
| Subnets | mgmt, priv-endpoints, (optional: firewall, gateway) | Network segmentation |
| NSGs | Per subnet | Traffic filtering |
| Log Analytics | `log-ops-hub` | Centralized logging |
| Private DNS Zones | blob, websites | Private endpoint resolution |

### Optional Resources (Disabled by Default)
- **Azure Firewall** - Set `enableFirewall: true` (requires Network Contributor)
- **Budget Alerts** - Set `deployBudget: true` with alert emails
- **Location Policy** - Set `deployPolicy: true`
- **RBAC Assignments** - Provide Entra group IDs

## IP Addressing

| Subnet | CIDR | Purpose |
|--------|------|---------|
| Management | 10.10.0.0/24 | Admin/jumpbox access |
| Private Endpoints | 10.10.1.0/24 | PaaS private connectivity |
| Firewall | 10.10.2.0/26 | Azure Firewall (if enabled) |
| Gateway | 10.10.3.0/27 | VPN/ExpressRoute (if needed) |

## Bicep Module Pattern

All modules follow this structure:
```
modules/{capability}/
├── main.bicep          # Module entry point
└── (supporting files)
```

Modules are called from `infra/envs/prod/main.bicep` using:
```bicep
module moduleName '../../modules/{capability}/main.bicep' = {
  scope: resourceGroup(rgName)
  name: 'deployment-name'
  params: { ... }
}
```

## Configuration

Edit `infra/envs/prod/parameters.prod.json` to customize:
- `location` - Azure region (default: southcentralus)
- `environment` - Environment tag (default: prod)
- `enableFirewall` - Deploy Azure Firewall (default: false)
- `networkAdminGroupId` / `networkOpsGroupId` - Entra group IDs for RBAC
- `tags` - Resource tagging

## Prerequisites

- PowerShell 5.1+
- Azure PowerShell (Az module)
- Bicep CLI (auto-installed if missing)
- **Permissions**: Owner or Contributor at subscription level

## Entra ID Setup (Optional)

Scripts in `infra/scripts/entra/`:
- `1-Setup-RbacGroups.ps1` - Creates security groups for RBAC
- `2-Setup-LabUsers.ps1` - Creates lab/test user accounts

## Post-Deployment

Run `verify.ps1` to validate:
1. Subscription context
2. Resource group existence
3. VNet and subnet configuration
4. NSG rules
5. Firewall status (if enabled)
6. Private DNS zones
7. Log Analytics workspace

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Deployment fails on firewall | Need Network Contributor role |
| RBAC not applied | Provide valid Entra group IDs |
| Bicep compilation fails | Run `az bicep upgrade` |
| Validation errors | Check parameter file syntax |

## Related Documentation

- `README.md` - Full solution documentation
- `QUICKSTART.md` - Rapid deployment guide
- `Deployps1-Readme.md` - Detailed deploy.ps1 usage
- `verifyps1-readme.md` - Verification script details
