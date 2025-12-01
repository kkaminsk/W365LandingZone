# Project Context

## Purpose

W365LandingZone provides Infrastructure-as-Code (IaC) for deploying Azure hub-and-spoke network architecture specifically designed for Windows 365 Cloud PC environments. The project implements Azure Landing Zone foundations with:

- **Hub Network** (`1_Hub/`) - Centralized connectivity, shared services, governance, and security controls
- **Windows 365 Spoke Network** (`2_Spoke/`) - Dedicated network infrastructure optimized for Cloud PC workloads
- **Multi-tenant Support** - Automatic, non-overlapping IP address allocation for up to 40 students/environments

### Goals
1. Provide production-ready Azure Landing Zone infrastructure for Windows 365
2. Enable rapid deployment of isolated student/tenant environments
3. Implement enterprise-grade security, governance, and monitoring
4. Support both standalone and hub-connected spoke deployments

## Tech Stack

### Infrastructure-as-Code
- **Azure Bicep** - Primary IaC language for all infrastructure definitions
- **ARM Templates** - Underlying deployment format (compiled from Bicep)
- **PowerShell 5.1+** - Deployment orchestration and automation scripts

### Azure Services
- Virtual Networks (VNets) with subnets
- Network Security Groups (NSGs)
- Azure Firewall (optional)
- Private DNS Zones
- Log Analytics Workspace
- Azure Policy
- RBAC (Role-Based Access Control)
- VNet Peering
- Service Endpoints (Storage, KeyVault)

### Development Tools
- Bicep CLI (template compilation)
- Azure PowerShell (Az module)
- Microsoft Graph PowerShell modules
- Git (version control)

## Project Conventions

### Code Style

#### Bicep Files
- Use 2-space indentation
- Place `targetScope` declaration at the top
- Group parameters, variables, resources, and outputs in that order
- Use descriptive parameter names with `@description` decorators
- Include `@allowed` validators where applicable

#### PowerShell Scripts
- Use `[CmdletBinding()]` for all functions
- Include full comment-based help (SYNOPSIS, DESCRIPTION, PARAMETER, EXAMPLE)
- Use `$ErrorActionPreference = 'Stop'` for fail-fast behavior
- Implement `-Validate` and `-WhatIf` parameters for deployment scripts
- Use colored `Write-Host` output for user feedback (Green=success, Yellow=warning, Red=error)

#### Naming Conventions
| Resource Type | Pattern | Example |
|---------------|---------|---------|
| Resource Groups | `rg-{purpose}-{type}` | `rg-hub-net`, `rg-spoke-net` |
| Virtual Networks | `vnet-{purpose}` | `vnet-hub`, `vnet-spoke` |
| Subnets | `snet-{purpose}` | `snet-cloudpc`, `snet-mgmt` |
| NSGs | `nsg-{subnet-name}` | `nsg-snet-cloudpc` |
| Log Analytics | `law-{purpose}` | `law-hub-monitoring` |

### Architecture Patterns

#### Hub-Spoke Topology
```
Hub Network (10.10.0.0/20)
├── Management Subnet (10.10.0.0/24)
├── Private Endpoints Subnet (10.10.1.0/24)
├── Firewall Subnet (10.10.2.0/26) - Optional
├── Gateway Subnet (10.10.3.0/27) - Optional
└── Shared Services (DNS, Log Analytics, Policy)
         │
         │ VNet Peering
         ▼
Spoke N (192.168.{N}.0/24)
├── Cloud PC Subnet (.0/26) - 62 IPs
├── Management Subnet (.64/26) - 62 IPs
├── AVD Subnet (.128/26) - Optional
└── Reserved (.192/26)
```

#### Module Structure
```
infra/
├── modules/
│   └── {capability}/
│       ├── main.bicep          # Module definition
│       └── README.md           # Module documentation
└── envs/
    └── {environment}/
        ├── main.bicep          # Orchestration template
        └── parameters.{env}.json
```

#### Deployment Pattern
1. Subscription-scoped deployments (both hub and spoke)
2. Resource groups created within deployment
3. Modular Bicep composition
4. Parameter-driven configuration

### Testing Strategy

#### Validation Levels
1. **Bicep Validation** - `.\deploy.ps1 -Validate` (syntax and schema)
2. **What-If Analysis** - `.\deploy.ps1 -WhatIf` (preview ARM changes)
3. **Post-Deployment Verification** - `.\verify.ps1` (resource state checks)
4. **Permission Verification** - `.\Check-W365Permissions.ps1` (RBAC validation)

#### Testing Requirements
- Always run `-Validate` before any deployment
- Use `-WhatIf` to review changes before production deployment
- Verify resource creation with `verify.ps1` after hub deployment
- Test with a single student number before bulk deployment

### Git Workflow

#### Branching Strategy
- `main` - Production-ready code
- Feature branches for new development
- Use OpenSpec for change management

#### Commit Conventions
- Use descriptive commit messages
- Reference related issues or specs
- Keep commits focused and atomic

## Domain Context

### Windows 365 Cloud PC
Windows 365 is Microsoft's cloud-based PC service. Key networking requirements:
- Outbound internet connectivity for Microsoft services
- Specific ports: 443 (HTTPS), 3389 (RDP internal)
- Azure AD/Entra ID integration
- Optional Azure AD Domain Services or hybrid AD join

### Azure Landing Zones
Enterprise-scale architecture pattern providing:
- Governance and compliance through Azure Policy
- Network topology (hub-spoke or Virtual WAN)
- Identity and access management
- Management and monitoring

### Multi-Student Environment
Designed for training/lab scenarios:
- Each student gets isolated /24 network
- Student number (1-40) determines IP range
- Automatic subnet calculation prevents conflicts
- Optional VNet peering to shared hub

## Important Constraints

### Technical Constraints
- Maximum 40 student environments (IP range limitation)
- Student numbers must be 1-40 (validated in deployment scripts)
- Hub must be deployed before spoke peering can be established
- Windows 365 service principal must exist for permissions assignment

### Security Constraints
- Follow least-privilege RBAC (use provided W365-MinimumRole.json)
- Do not hardcode credentials or subscription IDs in code
- NSG rules must allow Windows 365 required traffic
- Private DNS zones required for private endpoint resolution

### Azure Constraints
- Subscription-level deployments require appropriate permissions
- Some features require specific Azure AD roles (Global Admin for certain operations)
- Region availability varies for Azure services

## External Dependencies

### Azure Services
| Service | Purpose | Required |
|---------|---------|----------|
| Azure Resource Manager | Infrastructure deployment | Yes |
| Azure AD / Entra ID | Identity and RBAC | Yes |
| Windows 365 Service | Cloud PC provisioning | Yes (for spoke) |
| Microsoft Graph API | Permission management | Yes (for RBAC scripts) |

### PowerShell Modules
- `Az` - Azure PowerShell module
- `Az.Resources` - Resource management
- `Az.Network` - Network resource management
- `Microsoft.Graph` - Graph API access (for permission scripts)

### Documentation References
- [Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Windows 365 Network Requirements](https://learn.microsoft.com/windows-365/enterprise/requirements-network)
- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

## Current Implementation Status

### Hub (`1_Hub/`) - Complete
- [x] Resource group creation
- [x] Hub virtual network with subnets
- [x] Network Security Groups
- [x] Log Analytics Workspace
- [x] Private DNS Zones
- [x] Azure Policy assignments
- [x] RBAC role assignments
- [x] Budget and cost management
- [x] Diagnostic settings
- [x] Optional Azure Firewall
- [x] Deployment validation script
- [x] Post-deployment verification script

### Spoke (`2_Spoke/`) - Complete
- [x] Resource group creation
- [x] Spoke virtual network with subnets
- [x] Network Security Groups (W365-optimized)
- [x] Student number-based IP allocation
- [x] Windows 365 permission setup
- [x] Custom RBAC role definition
- [x] Permission verification script
- [x] Service endpoints configuration
- [x] Optional AVD subnet
- [x] VNet peering support (to hub)

### Documentation - Complete
- [x] Main README.md
- [x] QUICKSTART guides for hub and spoke
- [x] Architecture diagrams
- [x] IP addressing documentation
- [x] Permission and security guides
- [x] Deployment script documentation
