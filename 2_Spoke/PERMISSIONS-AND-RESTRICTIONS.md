# Windows 365 Spoke Network - Minimum Permissions & Resource Restrictions

This document outlines the absolute minimum permissions required for administrators to deploy the Windows 365 spoke network solution and recommended restrictions to limit resource sprawl and costs.

---

## Minimum Required Permissions

### Approach 1: Custom Role (Most Restrictive - Recommended)

Deploy the custom role definition for least-privilege access:

```powershell
# Create custom role scoped to specific resource group
$subscriptionId = "your-subscription-id"
$roleDefinition = Get-Content "W365-MinimumRole.json" | ConvertFrom-Json
$roleDefinition.AssignableScopes[0] = "/subscriptions/$subscriptionId/resourceGroups/rg-w365-spoke-prod"

# Create the custom role
New-AzRoleDefinition -InputFile "W365-MinimumRole.json"

# Assign to user
New-AzRoleAssignment `
    -SignInName "admin@contoso.com" `
    -RoleDefinitionName "Windows 365 Spoke Network Deployer" `
    -ResourceGroupName "rg-w365-spoke-prod"
```

**Permissions Included:**
- ✅ Create/manage virtual networks and subnets
- ✅ Create/manage network security groups
- ✅ Configure VNet peering
- ✅ Deploy Bicep templates
- ❌ **Cannot** affect resources outside designated RG
- ❌ **Cannot** modify subscription-level settings
- ❌ **Cannot** create VMs or other compute resources

---

### Approach 2: Built-in Roles (Simpler)

If custom roles aren't feasible, use built-in **Network Contributor** role scoped to resource group:

```powershell
$rgName = "rg-w365-spoke-prod"
$adminUser = "admin@contoso.com"

# Network Contributor - for network resource creation/management
New-AzRoleAssignment `
    -SignInName $adminUser `
    -RoleDefinitionName "Network Contributor" `
    -ResourceGroupName $rgName
```

**OR** use **Contributor** if the admin also needs to create the resource group:

```powershell
# Contributor at subscription level (only if creating new RG)
New-AzRoleAssignment `
    -SignInName $adminUser `
    -RoleDefinitionName "Contributor" `
    -Scope "/subscriptions/$subscriptionId"
```

**⚠️ Important:** 
- Use Network Contributor if resource group already exists
- Use Contributor (subscription-scoped) only if admin must create resource group
- Never grant broader permissions than necessary

---

### Resource Provider Registration

**One-time setup** (requires Subscription-level permissions):

```powershell
# Pre-register Microsoft.Network provider (done by subscription admin)
Register-AzResourceProvider -ProviderNamespace Microsoft.Network
```

If administrators cannot register providers, this must be pre-registered by a subscription owner.

---

## Windows 365 Service Principal Permissions

After deploying the network infrastructure, the Windows 365 service requires specific permissions to provision Cloud PCs:

### Required Permissions for Windows 365 Service

```powershell
# Automated script available
.\Set-W365Permissions.ps1

# Or manually assign these roles:
$w365ServicePrincipal = Get-AzADServicePrincipal -ApplicationId '0af06dc6-e4b5-4f28-818e-e78e62d137a5'

# 1. Reader on Subscription
New-AzRoleAssignment `
    -ObjectId $w365ServicePrincipal.Id `
    -RoleDefinitionName "Reader" `
    -Scope "/subscriptions/$subscriptionId"

# 2. Windows 365 Network Interface Contributor on Resource Group
New-AzRoleAssignment `
    -ObjectId $w365ServicePrincipal.Id `
    -RoleDefinitionName "Windows 365 Network Interface Contributor" `
    -ResourceGroupName "rg-w365-spoke-prod"

# 3. Windows 365 Network User on Virtual Network
$vnetId = (Get-AzVirtualNetwork -Name "vnet-w365-spoke-prod" -ResourceGroupName "rg-w365-spoke-prod").Id
New-AzRoleAssignment `
    -ObjectId $w365ServicePrincipal.Id `
    -RoleDefinitionName "Windows 365 Network User" `
    -Scope $vnetId
```

**Validation:**
```powershell
# Run the validation script
.\Check-W365Permissions.ps1
```

---

## Resource Restrictions & Limits

### 1. Azure Policy - Restrict VNet Address Spaces

Prevent unauthorized IP ranges:

**Policy: Allowed VNet Address Spaces**

```json
{
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Network/virtualNetworks"
        },
        {
          "not": {
            "field": "Microsoft.Network/virtualNetworks/addressSpace.addressPrefixes[*]",
            "in": [
              "192.168.100.0/24",
              "192.168.101.0/24",
              "192.168.102.0/24"
            ]
          }
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
}
```

---

### 2. Azure Policy - Restrict Regions

Limit deployments to specific Azure regions:

```powershell
$allowedLocations = @('canadacentral', 'eastus', 'westus3')

$policyDef = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Allowed locations' }

New-AzPolicyAssignment `
    -Name 'restrict-w365-locations' `
    -DisplayName 'W365: Allowed Regions' `
    -Scope "/subscriptions/$subscriptionId/resourceGroups/rg-w365-spoke-prod" `
    -PolicyDefinition $policyDef `
    -PolicyParameter @{
        listOfAllowedLocations = @{ value = $allowedLocations }
    }
```

---

### 3. Azure Policy - Require Tags

Enforce tagging for cost tracking and governance:

```json
{
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Network/virtualNetworks"
        },
        {
          "anyOf": [
            {
              "field": "tags['env']",
              "exists": "false"
            },
            {
              "field": "tags['workload']",
              "exists": "false"
            }
          ]
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
}
```

Apply with:

```powershell
New-AzPolicyAssignment `
    -Name 'require-w365-tags' `
    -DisplayName 'W365: Require Tags' `
    -Scope "/subscriptions/$subscriptionId/resourceGroups/rg-w365-spoke-prod" `
    -PolicyDefinition $policyDef
```

---

### 4. Budget Alerts

Create budget to prevent cost overruns:

```powershell
# Create budget for the resource group
$budgetScope = "/subscriptions/$subscriptionId/resourceGroups/rg-w365-spoke-prod"

# Use Azure CLI (Az PowerShell doesn't support budget creation)
az consumption budget create `
    --budget-name "w365-monthly-budget" `
    --amount 50 `
    --time-grain Monthly `
    --start-date (Get-Date).ToString("yyyy-MM-01") `
    --end-date "2026-12-31" `
    --resource-group "rg-w365-spoke-prod"
```

**Budget Alerts:**
- 80% threshold: Email to network team
- 100% threshold: Email to finance + network team
- Forecasted 100%: Email 5 days before end of month

---

### 5. Resource Locks

Protect persistent resources from accidental deletion:

```powershell
# Lock the resource group (delete protection)
New-AzResourceLock `
    -LockName "prevent-rg-deletion" `
    -LockLevel CanNotDelete `
    -ResourceGroupName "rg-w365-spoke-prod" `
    -LockNotes "Prevents accidental deletion of Windows 365 spoke network"

# Lock VNet specifically (read-only)
New-AzResourceLock `
    -LockName "vnet-readonly" `
    -LockLevel ReadOnly `
    -ResourceName "vnet-w365-spoke-prod" `
    -ResourceType "Microsoft.Network/virtualNetworks" `
    -ResourceGroupName "rg-w365-spoke-prod" `
    -LockNotes "VNet configuration is production-critical"
```

**⚠️ Note:** Use `ReadOnly` for production VNets to prevent any modifications. Use `CanNotDelete` for development/test environments.

---

### 6. NSG Rule Restrictions

Enforce baseline security rules via Azure Policy:

**Policy: Deny insecure NSG rules**

```json
{
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Network/networkSecurityGroups/securityRules"
        },
        {
          "anyOf": [
            {
              "allOf": [
                {
                  "field": "Microsoft.Network/networkSecurityGroups/securityRules/direction",
                  "equals": "Inbound"
                },
                {
                  "field": "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix",
                  "equals": "*"
                },
                {
                  "field": "Microsoft.Network/networkSecurityGroups/securityRules/access",
                  "equals": "Allow"
                }
              ]
            }
          ]
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
}
```

This prevents "Allow from Any" inbound rules.

---

### 7. Service Endpoint Policy

Control which Azure services the VNet can access:

```powershell
# Create service endpoint policy
$serviceEndpointPolicy = New-AzServiceEndpointPolicy `
    -ResourceGroupName "rg-w365-spoke-prod" `
    -Name "sep-w365-storage" `
    -Location "canadacentral"

# Add Storage account to allowed list
$storageAccount = Get-AzStorageAccount -ResourceGroupName "rg-storage" -Name "w365storage"
$policyDefinition = New-AzServiceEndpointPolicyDefinition `
    -Name "allow-w365-storage" `
    -Description "Allow access to W365 storage only" `
    -Service "Microsoft.Storage" `
    -ServiceResource $storageAccount.Id

Add-AzServiceEndpointPolicyDefinition `
    -ServiceEndpointPolicy $serviceEndpointPolicy `
    -ServiceEndpointPolicyDefinition $policyDefinition
```

---

## Permission Summary Matrix

| Operation | Custom Role | Network Contributor | Contributor |
|-----------|-------------|---------------------|-------------|
| **Deploy spoke VNet** | ✅ (RG-scoped) | ✅ (RG-scoped) | ✅ |
| **Register resource providers** | ❌ (pre-register) | ❌ (pre-register) | ✅ |
| **Create NSGs** | ✅ | ✅ | ✅ |
| **Configure VNet peering** | ✅ | ✅ | ✅ |
| **Create VMs** | ❌ | ❌ | ✅ |
| **Modify hub VNet** | ❌ | ❌ | ❌ (requires hub access) |
| **Access other RGs** | ❌ | ❌ | ✅ (if subscription-scoped) |

---

## Cost & Resource Constraints Summary

### Per Spoke Network Deployment
- **VNet:** $0 (no charge for VNet itself)
- **NSGs:** $0 (no charge for NSG rules)
- **VNet Peering:** ~$10-20/month (depending on traffic)
- **Service Endpoints:** $0 (no charge)

### Persistent Resources
- **Virtual Network:** 1 VNet with 3 subnets (Class C /24)
- **NSGs:** 3 NSGs (CloudPC, Management, AVD)
- **Peering:** Optional to hub network
- **Service Endpoints:** Storage and KeyVault enabled on CloudPC subnet

### Recommended Limits
- **Max VNets per RG:** 1
- **Max subnets per VNet:** 3-5
- **Max NSG rules per NSG:** 50 (review and consolidate regularly)
- **Max peerings per VNet:** 2-3
- **Monthly budget:** $50-100 (mostly peering costs)

---

## IP Address Plan Restrictions

### Enforce IP Address Standards

```powershell
# Policy to enforce specific address space
$ipRangePolicy = @{
    policyRule = @{
        if = @{
            allOf = @(
                @{
                    field = "type"
                    equals = "Microsoft.Network/virtualNetworks"
                },
                @{
                    not = @{
                        field = "Microsoft.Network/virtualNetworks/addressSpace.addressPrefixes[*]"
                        like = "192.168.*"
                    }
                }
            )
        }
        then = @{
            effect = "deny"
        }
    }
}
```

**Approved IP Ranges:**
- **W365 Spoke (Prod):** 192.168.100.0/24
- **W365 Spoke (Dev):** 192.168.101.0/24
- **W365 Spoke (Test):** 192.168.102.0/24

**Subnet Allocation:**
| Subnet | CIDR | IP Range | Usable IPs | Purpose |
|--------|------|----------|------------|---------|
| CloudPC | /26 | .0 - .63 | 62 | Windows 365 Cloud PCs |
| Management | /26 | .64 - .127 | 62 | Management resources |
| AVD | /26 | .128 - .191 | 62 | Azure Virtual Desktop (optional) |
| Reserved | - | .192 - .255 | 64 | Future expansion |

---

## Deployment Checklist

### 1. Pre-deployment (Subscription Admin)
- [ ] Pre-register Microsoft.Network resource provider
- [ ] Create dedicated resource group: `rg-w365-spoke-prod`
- [ ] Apply Azure Policies (IP ranges, regions, tags)
- [ ] Create budget with alerts
- [ ] Document IP address allocations

### 2. Grant Permissions (IAM Admin)
- [ ] Create custom role or use Network Contributor
- [ ] Scope role assignment to specific resource group only
- [ ] Verify admin cannot access other resource groups
- [ ] Test permissions with validation deployment

### 3. Apply Restrictions
- [ ] Apply resource locks to resource group
- [ ] Configure NSG baseline rules via policy
- [ ] Set up service endpoint policies (if needed)
- [ ] Enable Activity Log alerts for high-risk operations

### 4. Deploy Infrastructure
- [ ] Admin runs `.\deploy.ps1 -Validate`
- [ ] Admin runs `.\deploy.ps1`
- [ ] Verify deployment success
- [ ] Run `.\Set-W365Permissions.ps1` for Windows 365 service
- [ ] Run `.\Check-W365Permissions.ps1` to validate

### 5. Post-deployment
- [ ] Apply resource lock to VNet (`ReadOnly` or `CanNotDelete`)
- [ ] Document deployed resources
- [ ] Configure monitoring and alerts
- [ ] Update network documentation with IP allocations

---

## Troubleshooting Permission Issues

### "Insufficient permissions to register resource provider"
**Solution:** Pre-register `Microsoft.Network` provider at subscription level, or grant `Microsoft.Resources/subscriptions/providers/register/action`

### "Cannot create virtual network peering"
**Solution:** Administrator needs `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write` on both spoke and hub VNets

### "Authorization failed for VNet peering to hub"
**Solution:** Grant Network Contributor on hub VNet, or create peering from hub side with appropriate permissions

### "Policy prevented deployment"
**Solution:** Verify deployment complies with IP range, region, and tagging policies. Update parameters or request policy exception.

---

## Security Best Practices

1. **Principle of Least Privilege:** Use custom role scoped to single RG
2. **Separation of Networks:** Keep spoke networks isolated, connect via peering only
3. **NSG Baseline:** Enforce security rules via Azure Policy
4. **Service Endpoints:** Use for Azure PaaS services, avoid public endpoints
5. **Network Monitoring:** Enable NSG Flow Logs and Traffic Analytics
6. **Regular Review:** Review NSG rules and role assignments quarterly
7. **Hub-Spoke Topology:** Use hub for shared services, spokes for workloads
8. **MFA Required:** Enforce MFA for all network administrators

---

## Hub Peering Considerations

### Permissions Required for Hub Peering

**On Spoke Side:**
```powershell
# Spoke admin needs these permissions on spoke VNet
Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write
```

**On Hub Side:**
```powershell
# Hub admin needs to create reverse peering
New-AzVirtualNetworkPeering `
    -Name "peer-to-w365-spoke" `
    -VirtualNetwork (Get-AzVirtualNetwork -Name "vnet-hub") `
    -RemoteVirtualNetworkId "/subscriptions/.../vnet-w365-spoke-prod"
```

### Peering Configuration Restrictions

```powershell
# Policy: Prevent gateway transit on spokes
{
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Network/virtualNetworks/virtualNetworkPeerings"
        },
        {
          "field": "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/allowGatewayTransit",
          "equals": "true"
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
}
```

This prevents spoke networks from acting as transit points.

---

## Monitoring & Auditing

### Enable Network Watcher

```powershell
# Enable Network Watcher for region
$networkWatcher = New-AzNetworkWatcher `
    -ResourceGroupName "NetworkWatcherRG" `
    -Location "canadacentral" `
    -Name "NetworkWatcher_canadacentral"

# Enable NSG Flow Logs
$nsg = Get-AzNetworkSecurityGroup -Name "vnet-w365-spoke-prod-cloudpc-nsg" -ResourceGroupName "rg-w365-spoke-prod"
$storageAccount = Get-AzStorageAccount -ResourceGroupName "rg-monitoring" -Name "nsgflowlogs"

Set-AzNetworkWatcherConfigFlowLog `
    -NetworkWatcher $networkWatcher `
    -TargetResourceId $nsg.Id `
    -StorageAccountId $storageAccount.Id `
    -EnableFlowLog $true `
    -EnableTrafficAnalytics $true
```

### Activity Log Alerts

```powershell
# Alert on NSG rule changes
$actionGroup = Get-AzActionGroup -ResourceGroupName "rg-monitoring" -Name "NetworkAdmins"

New-AzActivityLogAlert `
    -ResourceGroupName "rg-monitoring" `
    -Name "alert-nsg-changes" `
    -Condition (New-AzActivityLogAlertCondition -Category "Administrative" -ResourceType "Microsoft.Network/networkSecurityGroups") `
    -Action $actionGroup `
    -Scope "/subscriptions/$subscriptionId/resourceGroups/rg-w365-spoke-prod"
```

---

## Quick Reference Commands

```powershell
# Check current permissions
Get-AzRoleAssignment -SignInName "admin@contoso.com" -ResourceGroupName "rg-w365-spoke-prod"

# Check applied policies
Get-AzPolicyAssignment -Scope "/subscriptions/$subscriptionId/resourceGroups/rg-w365-spoke-prod"

# Check resource locks
Get-AzResourceLock -ResourceGroupName "rg-w365-spoke-prod"

# Check budget status
az consumption budget list --resource-group "rg-w365-spoke-prod"

# Check resource provider registration
Get-AzResourceProvider -ProviderNamespace Microsoft.Network | Select-Object RegistrationState

# Audit recent deployments
Get-AzResourceGroupDeployment -ResourceGroupName "rg-w365-spoke-prod" | Select-Object DeploymentName, ProvisioningState, Timestamp

# Check Windows 365 permissions
.\Check-W365Permissions.ps1

# Assign Windows 365 permissions
.\Set-W365Permissions.ps1

# View NSG effective rules
Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceName "cloudpc-nic" -ResourceGroupName "rg-w365-spoke-prod"

# Check VNet peering status
Get-AzVirtualNetworkPeering -VirtualNetworkName "vnet-w365-spoke-prod" -ResourceGroupName "rg-w365-spoke-prod"
```

---

## Integration with Hub Network

If deploying in a hub-spoke topology, see the **Hub** folder for:
- Hub network deployment instructions
- Azure Firewall configuration
- DNS Private Zones setup
- ExpressRoute/VPN Gateway configuration

**Spoke networks should:**
- ✅ Use hub for egress traffic (via Azure Firewall)
- ✅ Use hub DNS (Private DNS Zones)
- ✅ Use hub for hybrid connectivity (ExpressRoute/VPN)
- ❌ Not have direct internet access (route via hub)
- ❌ Not have their own VPN/ExpressRoute gateways

---

**For questions or issues, refer to the main README.md or Deployps1-Readme.md**
