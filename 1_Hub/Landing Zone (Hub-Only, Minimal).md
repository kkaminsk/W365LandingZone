# Landing Zone (Hub-Only, Minimal)

## 1) Goals & Non-Goals

**Goals**

- Establish a small, secure hub for shared services and future spokes.
- Centralize identity, logging, and core network baseline.
- Keep cost/complexity low; ready for incremental growth.

**Non-Goals**

- No full SOC/SIEM stack, no complex connectivity (ExpressRoute), no advanced governance (CAF enterprise scale), no app workloads.

## 2) Scope & Assumptions

- Single Azure tenant and one subscription to start (can split later).
- Default region: choose 1 primary (e.g., `westus3`) with DR optional.
- Hub VNet only; spokes arrive later.

## 3) High-Level Architecture

```
+-------------------------------------------------------------+
|                  Azure Tenant (Entra ID)                    |
|  - Baseline CA policies, PIM, break-glass, SSPR/MFA         |
+------------------------+------------------------------------+
                         |
                         v
+-------------------------------------------------------------+
|                 Azure Subscription: platform-hub            |
|  RG: rg-hub-net       |  RG: rg-hub-ops                     |
|  - vnet-hub           |  - log-analytics (LAW)              |
|  - subnets:           |  - automation (optional)            |
|                                                             |
|    * GatewaySubnet (opt for VPN)                            |
|    * mgmt-snet                                              |
|    * priv-endpoints-snet                                    |
|  - NSGs/UDRs                                                |
|  - (opt) Azure Firewall or NVA                              |
|  - Private DNS Zones + DNS Private Resolver (opt)           |
+-------------------------------------------------------------+

Microsoft 365 Tenant
- Baseline security & compliance config
- Unified audit log to Entra/Azure integrations
```

## 4) Resource Inventory (Minimum)

### Subscriptions & Resource Groups

- **Subscription**: `sub-platform-hub`
- **RGs**
  - `rg-hub-net` – VNet, subnets, NSGs, route tables, (optional) Firewall/Bastion/VPN
  - `rg-hub-ops` – Log Analytics Workspace (LAW), DCRs, diagnostics, budgets/alerts

### Networking (Hub)

- **VNet**: `vnet-hub` (`10.10.0.0/20` as example)
- **Subnets**
  - `mgmt-snet` (`10.10.0.0/24`) – jump hosts, mgmt endpoints
  - `priv-endpoints-snet` (`10.10.1.0/24`) – Private Endpoints
  - `GatewaySubnet` (`/27`) *(optional – site-to-site VPN later)*
- **Security**
  - NSGs per subnet (deny inbound by default, allow required mgmt)
  - (Optional) **Azure Firewall Basic** for egress control + DNAT (smallest SKUs)
- **DNS**
  - Private DNS Zones for PaaS (e.g., `privatelink.azurewebsites.net`, etc.)
  - (Optional) Azure DNS Private Resolver if hybrid name resolution is planned

### Entra ID (Tenant Baseline)

- **Break-glass**: 2 cloud-only accounts, strong password, excluded from CA, monitored
- **Student Administrator Account**: Create a Student Administrator Account and assign to the `grp-w365-admin` group.
- **Student Test Account**: Create a Student Test Account 
- **MFA & CA** (minimal)
  - Require MFA for all users except break-glass
  - Block legacy auth
  - Require compliant or hybrid-joined devices for admins
  - Named Locations for Canada (and your office IPs if static)
- **Privileged Access**
  - PIM for built-in admin roles (at least Global Admin, Privileged Role Admin, Security Admin)
- **Authentication/Identity Hygiene**
  - SSPR enabled for users (MFA methods enforced)
  - Authentication Strengths: MFA (phishing-resistant if feasible: FIDO2/Passkeys)
  - Admin unit for platform admins (optional)
- **Groups/RBAC**
  - `grp-platform-network-admins` – Owner on `rg-hub-net`
  - `grp-platform-ops` – Contributor on `rg-hub-ops`
  - `grp-w365-admin` – Student Administrator Account and Intune administrator role assigned to the group.
  - `grp-w365-ops` – Empty group but assign the help desk operator role to the group from Intune.
  - Reader groups for auditors

### Log Analytics (Monitoring Minimum)

- **LAW**: `log-ops-hub` (region = hub region)
  - **Retention**: 30–90 days to start (cost-sensitive); uplift later
  - **DCRs**:
    - `dcr-azure-diags` – route platform resource logs/metrics to LAW
  - **Diagnostic Settings (must-have)**
    - VNet/NSG/Firewall/Bastion/VPN → LAW
    - Subscription `ActivityLog` → LAW
  - **Traffic Analytics (optional low-cost)** via NSG flow logs v2 to LAW or Storage
- **Budget/Alerts**
  - Monthly budget with 80%/100% alerts
  - Alert rules for Activity Log: Role assignments, Policy state non-compliant spike

### Microsoft 365 (Tenant Minimal Baseline)

- **Security Baseline**
  - Enable Unified Audit Log
  - Disable basic auth protocols (Exchange/SMTP legacy)
  - Safe Links/Safe Attachments *(if licensed; otherwise document gap)*
- **Role Segregation**
  - Exchange/SharePoint/Teams admin roles via PIM where possible
- **Data Governance (light)**
  - Default retention labels (optional), document classification pilot only

## 5) Governance & Policy (Small but Effective)

- **Azure Policy (built-ins where possible)**
  - Enforce resource tags: `costCenter`, `env`, `owner`
  - Allowed locations: `{canada-central, canada-east}` (or your pick)
  - Require diagnostic settings to LAW for supported resources
  - Audit public IP creation (or deny if you’ll use Firewall only)
  - Require Private Endpoints for selected PaaS (optional for phase 2)
- **RBAC**
  - No direct Owner on subscription except break-glass emergency process
  - Use group-based role assignments at RG scope (least privilege)

## 6) Naming Conventions

- **Pattern**: `{org}-{svc}-{scope}-{region}-{env}`
  - Example: `pf-hub-vnet-cac-prod`, `pf-hub-law-cac-prod`
- **Tags** (required): `env`, `owner`, `costCenter`, `dataSensitivity`

## 7) Cost Guardrails

- Start with **Firewall Basic** 
- Single LAW with 30d retention
- Budgets + cost alerts at subscription and RG levels

## 8) Security Baseline (Minimal)

- **Platform**
  - Defender for Cloud: free tier on (recommend Plan for Servers/Databases later)
  - Key vault for secrets if any shared creds appear (aim to avoid)
- **Identity**
  - CA policies live and monitored; break-glass tested quarterly
- **Access**
  - Just-in-time (PIM) for admin roles; no standing Global Admin

## 9) Day-2 Ops

- **Monitoring**: Review non-compliant policies weekly; cost dashboard monthly
- **Backups**: Not in scope (no stateful services). If jumpbox/Automation account added, enable Backup vault
- **Change Management**: PR-based IaC; changes via pipelines; tag changes with `changeId`
- **DR**: Not required at hub-only stage; document RTO/RPO as “N/A”

## 10) Deployment Approach (IaC-first)

### Repo Layout

```
/infra
  /modules
    /hub-network
    /monitoring
    /policy
  /envs
    /prod
      main.tf (or main.bicep)
```

### Terraform (sketch – hub essentials)

```hcl
# Providers & variables omitted for brevity

resource "azurerm_resource_group" "net" {
  name     = "rg-hub-net"
  location = var.location
}

resource "azurerm_resource_group" "ops" {
  name     = "rg-hub-ops"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "hub" {
  name                = "log-ops-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.ops.name
  sku                 = "PerGB2018"
  retention_in_days   = var.law_retention_days # e.g., 30
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = ["10.10.0.0/20"]
  tags                = var.tags
}

resource "azurerm_subnet" "mgmt" {
  name                 = "mgmt-snet"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.0.0/24"]
}

resource "azurerm_subnet" "priv" {
  name                 = "priv-endpoints-snet"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.1.0/24"]
  private_endpoint_network_policies = "Disabled"
}

# Example: Activity Log -> LAW
resource "azurerm_monitor_diagnostic_setting" "activity_to_law" {
  name                       = "activity-to-law"
  target_resource_id         = data.azurerm_subscription.primary.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id
  lifecycle { ignore_changes = [log, metric] }
}
```

### Bicep (tiny snippet – LAW + Activity Log)

```bicep
param location string = resourceGroup().location
param lawName  string = 'log-ops-hub'

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  properties: {
    retentionInDays: 30
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
    sku: { name: 'PerGB2018' }
  }
}

resource sub 'Microsoft.Resources/subscriptions@2020-01-01' existing = {
  scope: subscription()
}

resource actDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'activity-to-law'
  scope: sub
  properties: {
    workspaceId: law.id
    logs: [ { category: 'Administrative', enabled: true } ]
  }
}
```

## 11) Acceptance Criteria

- **Identity**: CA policies enforced; PIM enabled; 2 break-glass accounts documented & tested.
- **Network**: Hub VNet + required subnets; NSGs attached.
- **Logging**: Subscription Activity Logs + hub resources sending diagnostics to LAW; budget alerts active.
- **Governance**: Baseline policies assigned; tag compliance ≥95% after remediation.

