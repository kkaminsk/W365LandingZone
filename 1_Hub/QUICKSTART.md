# Quick Start Guide - PowerShell Deployment

## ✅ Your Bicep Code is Valid!

The validation passed successfully. You're ready to deploy.

## Quick Commands

### 1. Validate (Recommended First Step)
```powershell
.\deploy.ps1 -Validate
```
✅ **Status**: PASSED - No errors found

### 2. Preview Changes (What-If)
```powershell
.\deploy.ps1 -WhatIf
```
Shows what will be created/modified without making changes

### 3. Deploy
```powershell
.\deploy.ps1
```
Executes the actual deployment

## What Gets Deployed

Your hub landing zone includes:

### Resource Groups
- `rg-hub-net` - Network resources
- `rg-hub-ops` - Operations/monitoring resources

### Networking
- Virtual Network (`vnet-hub`) - 10.10.0.0/20
  - Management Subnet - 10.10.0.0/24
  - Private Endpoints Subnet - 10.10.1.0/24
  - Azure Firewall Subnet - 10.10.2.0/26 (if enabled)
  - Gateway Subnet - 10.10.3.0/27 (if enabled)
- Network Security Groups (2)
- Azure Firewall (Basic tier) - if enabled
- Public IP for Firewall

### Private DNS
- `privatelink.azurewebsites.net`
- `privatelink.blob.core.windows.net`
- Virtual Network Links

### Monitoring
- Log Analytics Workspace
- Subscription Activity Logs
- Diagnostic Settings

### Governance
- Azure Policy (Allowed Locations)
- Azure Budget ($200/month with alerts)
- RBAC Assignments (if group IDs provided)

## Pre-Deployment Checklist

- [_] Bicep code validated
- [_] Connected to Azure (W365Lab subscription)
- [_] Parameter file configured
- [_] Review what-if output
- [_] Ensure you have Owner/Contributor role
- [_] Verify subscription quota for resources

## Parameters You Can Customize

Edit `infra\envs\prod\parameters.prod.json`:

```json
{
  "location": "canada-central",           // Azure region
  "env": "prod",                          // Environment tag
  "allowedLocations": [...],              // Policy regions
  "networkAdminsGroupObjectId": "",       // AAD group for network admins
  "opsGroupObjectId": ""                  // AAD group for ops team
}
```

## Deployment Time

⏱️ Estimated: 5-10 minutes

Components deploy in this order:
1. Resource Groups (30 sec)
2. Log Analytics (1-2 min)
3. Virtual Network & Subnets (2-3 min)
4. Azure Firewall (2-4 min) - if enabled (default disabled)
5. Private DNS Zones (1 min)
6. Policies & Budgets (1 min)
7. RBAC & Diagnostics (1 min)

## Monitoring Deployment

### In PowerShell
Watch the verbose output in real-time

### In Azure Portal
1. Go to https://portal.azure.com
2. Navigate to **Subscriptions** → **Deployments**
3. Find deployment: `hub-deploy-YYYYMMDD-HHMMSS`

## After Deployment

### Get Deployment Outputs
```powershell
$deployment = Get-AzSubscriptionDeployment -Name "hub-deploy-*" | Sort-Object Timestamp -Descending | Select-Object -First 1
$deployment.Outputs
```

### Common Outputs
- `vnetId` - Resource ID of the hub VNet
- `lawId` - Resource ID of Log Analytics workspace

## Troubleshooting

### If Deployment Fails

1. **Check Error Message**: Read the red error output
2. **Review in Portal**: Check deployment details in Azure Portal
3. **Verify Permissions**: Ensure you have sufficient rights
4. **Check Quotas**: Verify subscription limits

### Rerun Deployment
```powershell
# Safe to rerun - Bicep is idempotent
.\deploy.ps1
```

### Clean Up (if needed)
```powershell
# Delete resource groups
Remove-AzResourceGroup -Name "rg-hub-net" -Force
Remove-AzResourceGroup -Name "rg-hub-ops" -Force
```

## Next Steps After Deployment

1. ✅ Verify all resources in Azure Portal
2. ✅ Review firewall rules (if deployed)
3. ✅ Configure additional NSG rules as needed
4. ✅ Set up monitoring alerts
5. ✅ Document IP addresses and resource IDs
6. ✅ Plan spoke VNet connectivity

## Support

- **Bicep Errors**: Check `get_errors` output in VS Code
- **Azure Issues**: Review deployment logs in Portal
- **PowerShell Help**: `Get-Help .\deploy.ps1 -Detailed`

---

**Ready to Deploy?**
```powershell
.\deploy.ps1
```
