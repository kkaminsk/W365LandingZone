# Hub Landing Zone

This folder contains the hub portion of the Windows 365 landing zone. It delivers the shared services, security boundaries, and governance scaffolding that underpin the Windows 365 spoke deployments.

## Solution Highlights

- **Subscription-level deployment** using Azure Bicep orchestrated by `deploy.ps1`
- **10.10.0.0/20 hub VNet** with management, private endpoints, firewall, and optional gateway subnets
- **Shared services**: Network Security Groups, Private DNS zones, Log Analytics workspace, diagnostic settings
- **Governance**: Optional Azure Policy, budget alerts, and RBAC assignments for network/ops groups
- **Automation**: PowerShell script handles parameter validation, tenant/subscription selection, and optional Azure Firewall enablement

## Folder Structure

| Item | Description |
|------|-------------|
| `deploy.ps1` | Main deployment script (validate/what-if/deploy) |
| `verify.ps1` | Post-deployment validation script |
| `QUICKSTART.md` | One-page deployment guide with essential commands |
| `Deployps1-Readme.md` | Detailed documentation for `deploy.ps1` |
| `verifyps1-readme.md` | Troubleshooting and usage guide for verification script |
| `plan.md` | Planning notes and deployment considerations |
| `infra/` | Bicep templates, modules, and environment parameters |
| `scripts/` | Helper scripts (RBAC assignments, user bootstrap, etc.) |

## Prerequisites

1. **Azure PowerShell (`Az`)** module installed and imported
2. **Bicep CLI** available on PATH (script checks and installs if needed)
3. **Azure subscription access**
   - Owner or Contributor at subscription scope
   - Network Contributor if enabling Azure Firewall
4. Updated parameters file: `infra/envs/prod/parameters.prod.json`

Example parameter values:
```json
{
  "location": { "value": "canadacentral" },
  "env": { "value": "prod" },
  "allowedLocations": { "value": ["canadacentral", "canadaeast"] },
  "networkAdminsGroupObjectId": { "value": "<aad-group-id>" },
  "opsGroupObjectId": { "value": "<aad-group-id>" },
  "enableFirewall": { "value": false }
}
```

## Deployment Workflow

1. **Validate templates** (recommended)
   ```powershell
   cd 1_Hub
   .\deploy.ps1 -Validate
   ```
2. **Preview changes** (optional what-if)
   ```powershell
   .\deploy.ps1 -WhatIf
   ```
3. **Deploy hub landing zone**
   ```powershell
   .\deploy.ps1
   ```
4. **Review outputs** for VNet IDs, Log Analytics IDs, etc.
   ```powershell
   $deployment = Get-AzSubscriptionDeployment -Name "hub-deploy-*" | Sort-Object Timestamp -Descending | Select-Object -First 1
   $deployment.Outputs
   ```
5. **Verify resources** (optional but recommended)
   ```powershell
   .\verify.ps1
   ```

## Customization Tips

- Set `enableFirewall` to `true` only after assigning Network Contributor permissions to the deploying identity.
- Supply `networkAdminsGroupObjectId` and `opsGroupObjectId` to automate RBAC assignments.
- Use `-Location` parameter on the script to override the default Azure region.
- For multi-tenant scenarios, pass `-TenantId` and `-SubscriptionId` or follow the script prompts.

## Troubleshooting

- **Validation errors**: rerun `./deploy.ps1 -Validate` and inspect detailed error output.
- **Region format issues**: use condensed names (e.g., `canadacentral`, not `canada-central`).
- **Firewall permission failures**: keep firewall disabled or grant required `Microsoft.Network/virtualNetworks/subnets/join/action` permission.
- **Authentication**: run `Connect-AzAccount` with the correct tenant before rerunning the script.

See `Deployps1-Readme.md` and `verifyps1-readme.md` for exhaustive troubleshooting guidance.

## Related Documentation

- [QUICKSTART.md](./QUICKSTART.md)
- [Deployps1-Readme.md](./Deployps1-Readme.md)
- [verifyps1-readme.md](./verifyps1-readme.md)
- [Landing Zone (Hub-Only, Minimal).md](./Landing%20Zone%20(Hub-Only,%20Minimal).md)

Use this README as the entry point for anyone working specifically inside the `1_Hub` solution.
