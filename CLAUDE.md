# CLAUDE.md - Claude Code Project Guide

## Project Overview

W365LandingZone is an Infrastructure-as-Code (IaC) repository for deploying Azure hub-and-spoke network architecture for Windows 365 Cloud PC environments. It implements Azure Landing Zone foundations with multi-tenant support for up to 40 students/environments.

## Technology Stack

- **Primary Language**: Azure Bicep (IaC)
- **Scripting**: PowerShell 5.1+
- **Cloud Platform**: Microsoft Azure
- **Key Azure Services**: Virtual Networks, NSGs, Azure Firewall, Private DNS, Log Analytics, Azure Policy, RBAC

## Project Structure

```
W365LandingZone/
├── 1_Hub/                    # Hub landing zone (centralized connectivity)
│   ├── deploy.ps1            # Hub deployment entry point
│   ├── verify.ps1            # Post-deployment validation
│   └── infra/
│       ├── modules/          # Reusable Bicep modules
│       └── envs/prod/        # Production environment config
├── 2_Spoke/                  # Windows 365 spoke network
│   ├── deploy.ps1            # Spoke deployment entry point
│   ├── Setup-MinimumPermissions.ps1
│   ├── Set-W365Permissions.ps1
│   ├── Check-W365Permissions.ps1
│   └── infra/
│       ├── modules/          # Spoke-specific modules
│       └── envs/prod/        # Production environment config
├── openspec/                 # Spec-driven development framework
│   ├── changes/              # Proposed changes
│   └── specs/                # Current specifications
└── Graphics/                 # Documentation diagrams
```

## Key Commands

```powershell
# Hub Deployment
cd 1_Hub
.\deploy.ps1 -Validate        # Validate only
.\deploy.ps1 -WhatIf          # Preview changes
.\deploy.ps1                  # Full deployment

# Spoke Deployment (requires StudentNumber 1-40)
cd 2_Spoke
.\deploy.ps1 -Validate -StudentNumber 1
.\deploy.ps1 -StudentNumber 1

# Permission Scripts
.\Setup-MinimumPermissions.ps1 -SubscriptionId "xxx" -AdminEmail "admin@contoso.com"
.\Set-W365Permissions.ps1
.\Check-W365Permissions.ps1
```

## Development Patterns

### Bicep Conventions
- Modules located in `infra/modules/[capability]/main.bicep`
- Environment configs in `infra/envs/[env]/parameters.[env].json`
- Subscription-scoped deployments for both hub and spoke
- Use existing module patterns when adding new infrastructure

### Naming Conventions
- Resource Groups: `rg-{purpose}-{type}` (e.g., `rg-hub-net`, `rg-spoke-net`)
- VNets: `vnet-{purpose}` (e.g., `vnet-hub`, `vnet-spoke`)
- Subnets: `snet-{purpose}` (e.g., `snet-cloudpc`, `snet-mgmt`)
- NSGs: `nsg-{subnet-name}`

### IP Addressing
- Hub: `10.10.0.0/20`
- Spokes: `192.168.{StudentNumber}.0/24` (auto-calculated)
  - Cloud PC: `.0/26` (62 IPs)
  - Management: `.64/26` (62 IPs)
  - AVD: `.128/26` (optional)
  - Reserved: `.192/26`

### PowerShell Standards
- Use `[CmdletBinding()]` for all functions
- Include proper parameter validation
- Add full help documentation (SYNOPSIS, DESCRIPTION, EXAMPLE)
- Use colored output for user feedback
- Implement `-Validate` and `-WhatIf` flags for deployments

## Important Files

| File | Purpose |
|------|---------|
| `1_Hub/deploy.ps1` | Hub deployment orchestrator |
| `2_Spoke/deploy.ps1` | Spoke deployment orchestrator |
| `1_Hub/infra/envs/prod/main.bicep` | Hub main template |
| `2_Spoke/infra/envs/prod/main.bicep` | Spoke main template (contains student number logic) |
| `2_Spoke/W365-MinimumRole.json` | Custom RBAC role definition |

## Testing & Validation

1. Always run `-Validate` before deployment
2. Use `-WhatIf` to preview ARM changes
3. Run `verify.ps1` after hub deployment
4. Run `Check-W365Permissions.ps1` after spoke permissions setup

## Security Considerations

- Follow least-privilege RBAC (use W365-MinimumRole.json)
- NSG rules are pre-configured for Windows 365 traffic
- Service endpoints enabled for Storage and KeyVault
- Private DNS zones support private endpoints
- Do not hardcode credentials or subscription IDs

## Documentation

Comprehensive docs exist in each solution folder:
- `QUICKSTART.md` - Rapid deployment guide
- `README.md` - Full documentation
- `Deployps1-Readme.md` - Deployment script details
- `ARCHITECTURE-DIAGRAM.md` - Network topology (spoke)
- `IP-ADDRESSING.md` - IP allocation scheme (spoke)

## OpenSpec Workflow

This project uses spec-driven development:
- Proposed changes go in `openspec/changes/`
- Approved specs live in `openspec/specs/`
- Follow conventions in `openspec/project.md`
