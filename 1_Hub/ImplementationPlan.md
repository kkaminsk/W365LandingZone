# Bicep Implementation Plan — Minimal Hub Landing Zone

This plan turns the requirements in `Landing Zone (Hub-Only, Minimal).md` into a modular Bicep implementation that deploys a minimal hub for networking, monitoring, governance, and RBAC. Entra ID and Microsoft 365 items are called out as non-Bicep tasks with suggested automation paths.

## 1) Scope

- Azure hub only (VNet, subnets, NSGs, Firewall Basic, Private DNS, Log Analytics, diagnostics, policy, budgets, RBAC).
- One tenant and one subscription to start.
- Entra ID Conditional Access, PIM, break‑glass accounts, Student accounts/groups, and M365 baseline are out-of-scope for Bicep and require Entra/Microsoft Graph or manual steps.

## 2) Repository Layout

```text
/infra
  /modules
    /rg                         # Create resource groups (sub scope)
    /hub-network                # VNet, subnets, NSGs, UDRs (opt), Firewall Basic (opt)
    /private-dns                # Private DNS zones + VNet links
    /log-analytics              # LAW + retention + DCR
    /diagnostics                # Resource + Subscription diagnostic settings → LAW
    /policy                     # Built-in policy assignments
    /rbac                       # Group-based role assignments at RG scope
    /budget                     # Subscription and RG budgets
    /defender                   # (Optional) Defender for Cloud pricing configs
    /nsg-flowlogs               # (Optional) NSG flow logs v2 / Traffic Analytics
    /dns-private-resolver       # (Optional) Azure DNS Private Resolver
  /envs
    /prod
      main.bicep                # Orchestrates all modules
      parameters.prod.jsonc     # Parameter values for prod
/scripts
  /entra                        # (Out-of-scope for Bicep) Graph/PowerShell for CA, PIM, users, group role assigns
```

## 3) Modules — Responsibilities and Key Resources

- **`rg` (targetScope: subscription)**
  - Create resource groups: `rg-hub-net`, `rg-hub-ops` (region = primary).

- **`hub-network` (targetScope: resourceGroup)**
  - `vnet-hub` address space `10.10.0.0/20`.
  - Subnets: `mgmt-snet` `10.10.0.0/24`, `priv-endpoints-snet` `10.10.1.0/24`, optional `GatewaySubnet` `/27`.
  - NSGs per subnet (deny by default; param-driven minimal inbound from named admin IP prefixes).
  - Optional UDRs.
  - Optional Azure Firewall Basic (default: enabled per cost guardrail). Expose private IP output for UDR default route if needed.

- **`private-dns` (targetScope: resourceGroup)**
  - Create Private DNS zones for common PaaS: `privatelink.azurewebsites.net`, `privatelink.blob.core.windows.net`, etc. (parameterized list).
  - Link to hub VNet.

- **`log-analytics` (targetScope: resourceGroup)**
  - LAW `log-ops-hub`, SKU `PerGB2018`, retention 30 days (default), parameterized 30–90.
  - Create DCR `dcr-azure-diags` for platform resources.

- **`diagnostics` (mixed scopes)**
  - Subscription Activity Log → LAW diagnostic setting.
  - Resource diagnostic settings for VNet/NSG/Firewall/VPN/Bastion (as applicable) → LAW.

- **`policy` (targetScope: subscription)**
  - Assign built-ins:
    - Enforce required tags: `env`, `owner`, `costCenter`, `dataSensitivity` (policy params).
    - Allowed locations: e.g., `canada-central`, `canada-east` (parameterized).
    - Require diagnostic settings to LAW for supported resources.
    - Audit or Deny public IP creation (parameterized effect).
    - (Phase 2) Require Private Endpoints for selected PaaS.

- **`rbac` (targetScope: subscription)**
  - Group-based role assignments at RG scope:
    - `grp-platform-network-admins` → Owner on `rg-hub-net`.
    - `grp-platform-ops` → Contributor on `rg-hub-ops`.
    - Optional Reader groups for auditors.
  - Inputs are Entra group object IDs (Bicep will not create Entra groups).

- **`budget` (targetScope: subscription)**
  - Subscription monthly budget with 80%/100% alerts.
  - Optional RG-level budgets for `rg-hub-net` and `rg-hub-ops`.

- **Optional**
  - `defender`: keep free tier or enable plans later.
  - `nsg-flowlogs`: enable NSG flow logs v2 to LAW or Storage (Traffic Analytics optional).
  - `dns-private-resolver`: deploy if hybrid name resolution planned.

## 4) Parameters (summarized)

- **Global**: `location`, `env`, `tags` (must include `env`, `owner`, `costCenter`, `dataSensitivity`).
- **Naming**: `org`, `svc`, `scope`, `regionShort` to compose `{org}-{svc}-{scope}-{region}-{env}`.
- **Network**: `vnetAddressSpace`, `mgmtSubnetPrefix`, `privEndpointsSubnetPrefix`, `enableGatewaySubnet`, `gatewaySubnetPrefix`, `adminSourcePrefixes`.
- **Firewall**: `enableFirewall` (default true), `firewallSku` (Basic), optional `firewallPolicy` and minimal rule collections.
- **Monitoring**: `lawName`, `lawRetentionDays` (default 30), `dcrName`.
- **Policy**: `allowedLocations`, `requiredTags`, `requireDiagnostics` (bool), `publicIpEffect` (`Audit` or `Deny`).
- **RBAC**: `networkAdminsGroupObjectId`, `opsGroupObjectId`, `auditorsGroupObjectId` (optional).
- **Budgets**: `subscriptionBudgetAmount`, `rgNetBudgetAmount`, `rgOpsBudgetAmount`.

## 5) Orchestration and Scopes

`envs/prod/main.bicep` composes modules with explicit scopes:

- Subscription-scope modules: `rg`, `policy`, `budget`, `rbac`, subscription `diagnostics`, optional `defender`.
- RG-scope modules: `log-analytics` (in `rg-hub-ops`), `hub-network` and `private-dns` (in `rg-hub-net`), resource `diagnostics`.

## 6) Deployment Order

1. Resource Groups (`rg`).
2. Log Analytics (`log-analytics`) in `rg-hub-ops`.
3. Hub Network (`hub-network`) in `rg-hub-net` (Firewall Basic enabled by default).
4. Private DNS (`private-dns`) and VNet links.
5. Diagnostics (`diagnostics`): subscription Activity Log and resource diagnostics → LAW.
6. Budgets (`budget`).
7. Policy Assignments (`policy`).
8. RBAC (`rbac`).
9. Optional: `nsg-flowlogs`, `defender`, `dns-private-resolver`.

## 7) Example — `envs/prod/main.bicep` (outline)

```bicep
param location string
param env string
param tags object

// Resource group creation at subscription scope
module rg '../modules/rg/main.bicep' = {
  name: 'rg'
  scope: subscription()
  params: {
    location: location
    rgNetName: 'rg-hub-net'
    rgOpsName: 'rg-hub-ops'
    tags: tags
  }
}

// LAW
module law '../modules/log-analytics/main.bicep' = {
  name: 'log'
  scope: resourceGroup(rg.outputs.rgOpsId)
  params: {
    location: location
    name: 'log-ops-hub'
    retentionDays: 30
    tags: tags
  }
}

// VNet + Firewall
module net '../modules/hub-network/main.bicep' = {
  name: 'net'
  scope: resourceGroup(rg.outputs.rgNetId)
  params: {
    location: location
    vnetAddressSpace: '10.10.0.0/20'
    mgmtSubnetPrefix: '10.10.0.0/24'
    privEndpointsSubnetPrefix: '10.10.1.0/24'
    enableGatewaySubnet: false
    enableFirewall: true
    tags: tags
  }
}

// Private DNS zones + link to VNet
module pdns '../modules/private-dns/main.bicep' = {
  name: 'pdns'
  scope: resourceGroup(rg.outputs.rgNetId)
  params: {
    vnetId: net.outputs.vnetId
    zones: [
      'privatelink.azurewebsites.net'
      'privatelink.blob.core.windows.net'
    ]
    tags: tags
  }
}

// Subscription Activity Log → LAW
module subDiag '../modules/diagnostics/subscription.bicep' = {
  name: 'sub-diag'
  scope: subscription()
  params: {
    lawId: law.outputs.lawId
  }
}

// Resource diagnostics → LAW
module resDiag '../modules/diagnostics/resources.bicep' = {
  name: 'res-diag'
  scope: resourceGroup(rg.outputs.rgNetId)
  params: {
    resourceIds: [ net.outputs.vnetId ]
    lawId: law.outputs.lawId
  }
}

// Policy, RBAC, Budgets omitted for brevity (similar pattern)
```

## 8) Parameters file — `envs/prod/parameters.prod.jsonc` (sample)

```jsonc
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": { "value": "canada-central" },
    "env": { "value": "prod" },
    "tags": {
      "value": {
        "env": "prod",
        "owner": "platform-team",
        "costCenter": "1000",
        "dataSensitivity": "internal"
      }
    },
    "subscriptionBudgetAmount": { "value": 200 },
    "rgNetBudgetAmount": { "value": 50 },
    "rgOpsBudgetAmount": { "value": 50 },
    "allowedLocations": { "value": ["canada-central", "canada-east"] },
    "publicIpEffect": { "value": "Audit" }
  }
}
```

## 9) Non‑Bicep Tasks (Entra ID / M365)

- Create and protect 2 break-glass accounts (exclude from CA; monitor).
- Create Student Administrator Account and Student Test Account; add Student Admin to `grp-w365-admin`.
- Assign Intune roles: `grp-w365-admin` → Intune Administrator; `grp-w365-ops` → Help Desk Operator.
- Configure Conditional Access (MFA required, block legacy auth, device state for admins, named locations for Canada/office IPs).
- Enable SSPR with MFA methods and authentication strengths (FIDO2/Passkeys if feasible).
- Enable Unified Audit Log; disable legacy basic auth (Exchange/SMTP) where applicable.
- Recommended automation: Microsoft Graph PowerShell/CLI under `/scripts/entra` with documentation.

## 10) Validation Checklist (maps to Acceptance Criteria)

- Identity: CA policies live; PIM enabled; 2 break‑glass documented and tested; Student accounts exist and group membership set (non-Bicep).
- Network: Hub VNet + `mgmt-snet` + `priv-endpoints-snet`; NSGs attached; Firewall Basic deployed if `enableFirewall=true`.
- Logging: Subscription Activity Log and hub resources send diagnostics to `log-ops-hub`; budgets created; alerts at 80%/100%.
- Governance: Policy assignments active; required tags auto‑remediated; compliance ≥95%.

## 11) CLI Commands (subscription-scope deploy)

```bash
# What-if
az deployment sub what-if \
  --name hub-minimal-whatif \
  --location canada-central \
  --template-file infra/envs/prod/main.bicep \
  --parameters @infra/envs/prod/parameters.prod.jsonc

# Deploy
az deployment sub create \
  --name hub-minimal-deploy \
  --location canada-central \
  --template-file infra/envs/prod/main.bicep \
  --parameters @infra/envs/prod/parameters.prod.jsonc
```

---

If you want, I can scaffold the `/infra/modules` and `/envs/prod` files next so you can deploy immediately.
