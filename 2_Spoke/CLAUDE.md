# CLAUDE.md - 2_Spoke Solution Guide

## Solution Overview

The 2_Spoke folder contains the Windows 365 spoke network deployment for the Azure hub-and-spoke landing zone. It provisions isolated virtual networks for up to 40 students/environments, each with pre-configured subnets, NSGs, and Windows 365 permissions.

## Folder Structure

```
2_Spoke/
├── deploy.ps1                    # Main deployment orchestrator
├── Setup-MinimumPermissions.ps1  # Security setup automation
├── Set-W365Permissions.ps1       # W365 service principal permissions
├── Check-W365Permissions.ps1     # Permission validation script
├── W365-MinimumRole.json         # Custom RBAC role definition
└── infra/
    ├── modules/
    │   ├── rg/main.bicep              # Resource group module
    │   ├── spoke-network/main.bicep   # VNet, subnets, NSGs
    │   └── w365-permissions/main.bicep # W365 permission assignments
    └── envs/prod/
        ├── main.bicep                 # Main orchestration template
        ├── main.json                  # Compiled ARM template
        └── parameters.prod.json       # Production configuration
```

## Key Commands

```powershell
# Basic deployment (StudentNumber 1-40 required)
.\deploy.ps1 -StudentNumber 1

# Validate template only
.\deploy.ps1 -Validate -StudentNumber 1

# Preview changes without deploying
.\deploy.ps1 -WhatIf -StudentNumber 1

# Deploy to specific subscription/tenant
.\deploy.ps1 -SubscriptionId "xxx" -TenantId "yyy" -StudentNumber 5

# Deploy to different region
.\deploy.ps1 -Location "eastus" -StudentNumber 1

# Permission scripts
.\Setup-MinimumPermissions.ps1 -SubscriptionId "xxx" -AdminEmail "admin@contoso.com"
.\Set-W365Permissions.ps1
.\Check-W365Permissions.ps1
```

## IP Addressing Scheme

Each student gets a unique `/24` network automatically calculated from their student number:

| Subnet | CIDR Pattern | Usable IPs | Example (Student 5) |
|--------|--------------|------------|---------------------|
| Cloud PC | `.0/26` | 62 | 192.168.5.0/26 |
| Management | `.64/26` | 62 | 192.168.5.64/26 |
| AVD (optional) | `.128/26` | 62 | 192.168.5.128/26 |
| Reserved | `.192/26` | 64 | 192.168.5.192/26 |

**Hub Network**: `10.10.0.0/20` (shared, deployed separately via 1_Hub)

## Bicep Module Architecture

### Main Template (`infra/envs/prod/main.bicep`)
- **Scope**: Subscription-level
- **Key Parameters**:
  - `studentNumber` (1-40): Drives IP calculation
  - `enableAvdSubnet`: Toggle AVD subnet creation
  - `hubVnetId`: Hub VNet ID for peering
  - `windows365ServicePrincipalId`: W365 service principal

### Modules Called
1. **rg** - Creates resource group `rg-w365-spoke-student{N}-{env}`
2. **spoke-network** - Creates VNet, subnets, NSGs, optional peering
3. **w365-permissions** - Assigns Windows 365 RBAC roles

## Security Configuration

### NSG Rules (Pre-configured)
- **Cloud PC**: RDP inbound from VNet, HTTPS/DNS outbound
- **Management**: HTTPS inbound from VNet
- **AVD**: RDP inbound from VNet

### Service Endpoints
- Microsoft.Storage (Cloud PC subnet)
- Microsoft.KeyVault (Cloud PC subnet)

### Required Permissions

| Role | Scope | Purpose |
|------|-------|---------|
| Contributor OR Custom Role | Subscription | Deploy resources |
| W365 Network Interface Contributor | Resource Group | Manage NICs |
| W365 Network User | VNet | Join devices to network |

## Naming Conventions

- **Resource Group**: `rg-w365-spoke-student{N}-{env}`
- **VNet**: `vnet-w365-spoke-student{N}-{env}`
- **Subnets**: `snet-cloudpc`, `snet-mgmt`, `snet-avd`
- **NSGs**: `{vnetname}-{subnet}-nsg`
- **Peering**: `peer-to-hub`

## Key Files Reference

| File | Purpose |
|------|---------|
| `deploy.ps1` | Main entry point - handles auth, validation, deployment |
| `infra/envs/prod/main.bicep` | Master template with student number logic |
| `infra/modules/spoke-network/main.bicep` | VNet/subnet/NSG creation |
| `parameters.prod.json` | Environment configuration |
| `W365-MinimumRole.json` | Custom least-privilege RBAC definition |

## Development Guidelines

### Modifying IP Ranges
Edit the calculation in `infra/envs/prod/main.bicep`:
```bicep
var spokeAddressPrefix = '192.168.${studentNumber}.0/24'
```

### Adding NSG Rules
Edit `infra/modules/spoke-network/main.bicep` security rules arrays.

### Enabling Hub Peering
Set `hubVnetId` in `parameters.prod.json` to the hub VNet resource ID.

### Adding New Subnets
1. Add subnet definition in `spoke-network/main.bicep`
2. Add corresponding NSG
3. Update outputs in both module and main template

## Validation Checklist

1. Run `-Validate` before any deployment
2. Run `-WhatIf` to preview ARM changes
3. Verify student number is unique (1-40)
4. Run `Check-W365Permissions.ps1` after permission setup
5. Confirm hub peering if cross-network connectivity needed

## Documentation Index

| Document | Purpose |
|----------|---------|
| QUICKSTART.md | 3-step fast deployment |
| README.md | Full project overview |
| Deployps1-Readme.md | Detailed deployment guide |
| ARCHITECTURE-DIAGRAM.md | Network topology diagrams |
| IP-ADDRESSING.md | Multi-student IP scheme |
| PERMISSIONS-AND-RESTRICTIONS.md | Security & RBAC guide |
