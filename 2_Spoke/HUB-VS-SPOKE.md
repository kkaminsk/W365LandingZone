# Hub vs Spoke: Architecture Comparison

This document explains the differences between the Hub and W365 Spoke deployments.

## 🏗️ Architecture Overview

```
Hub Network (10.10.0.0/20)
    ├── Management Subnet
    ├── Private Endpoints Subnet
    ├── Azure Firewall Subnet (optional)
    └── Gateway Subnet (optional)
    
W365 Spoke Network (192.168.{N}.0/24) where N=student number
    ├── Cloud PC Subnet
    ├── Management Subnet
    └── AVD Subnet (optional)
    
    [Optional VNet Peering between Hub ↔ Spoke]
```

## 📊 Key Differences

| Feature | Hub Network | W365 Spoke Network |
|---------|-------------|-------------------|
| **Purpose** | Central connectivity & security | Windows 365 Cloud PC hosting |
| **Address Space** | 10.10.0.0/20 (4,096 IPs) | 192.168.{N}.0/24 (256 IPs, N=student 1-40) |
| **Deployment Scope** | Subscription-level | Subscription-level |
| **Resource Groups** | 2 (network + ops) | 1 (spoke only) |
| **Azure Firewall** | Yes (optional) | No |
| **Private DNS** | Yes | No (uses hub's DNS) |
| **Log Analytics** | Yes | No (uses hub's workspace) |
| **Budget Monitoring** | Yes (optional) | No |
| **Policy Assignment** | Yes (optional) | No |
| **VNet Peering** | Hub side | Spoke side |

## 🔐 Permission Requirements

### Hub Deployment

**Required**:
- Owner or Contributor at subscription level
- `Microsoft.Resources/deployments/validate/action`

**Optional** (for firewall):
- Network Contributor role
- `Microsoft.Network/virtualNetworks/subnets/join/action`

### Spoke Deployment

**Required** (less restrictive):
- Contributor role at subscription level
  
**OR**:
- Network Contributor role
- Permission to create resource groups

## 🎯 When to Use Each

### Use Hub Network When:
- ✅ Building central connectivity infrastructure
- ✅ Need Azure Firewall for security
- ✅ Centralizing private DNS zones
- ✅ Implementing hub-spoke topology
- ✅ Need shared services (VPN, ExpressRoute)

### Use W365 Spoke Network When:
- ✅ Deploying Windows 365 Cloud PCs
- ✅ Need isolated network for specific workload
- ✅ Want simpler deployment with fewer permissions
- ✅ Building multi-spoke architecture
- ✅ Testing or dev environments

## 🔗 Hub-Spoke Integration

### Step 1: Deploy Hub (if not already deployed)

```powershell
cd Hub
.\deploy.ps1
```

### Step 2: Deploy W365 Spoke

```powershell
cd W365
.\deploy.ps1
```

### Step 3: Configure Peering (Spoke to Hub)

Update `W365/infra/envs/prod/parameters.prod.json`:

```json
{
  "hubVnetId": { 
    "value": "/subscriptions/{sub-id}/resourceGroups/rg-hub-net/providers/Microsoft.Network/virtualNetworks/vnet-hub"
  }
}
```

Redeploy:
```powershell
.\deploy.ps1
```

### Step 4: Configure Peering (Hub to Spoke)

In the Hub VNet, create peering to spoke:

```powershell
# PowerShell example
New-AzVirtualNetworkPeering `
  -Name "peer-to-w365-spoke" `
  -VirtualNetwork (Get-AzVirtualNetwork -Name "vnet-hub" -ResourceGroupName "rg-hub-net") `
  -RemoteVirtualNetworkId "/subscriptions/{sub-id}/resourceGroups/rg-w365-spoke-student1-prod/providers/Microsoft.Network/virtualNetworks/vnet-w365-spoke-student1-prod" `
  -AllowForwardedTraffic `
  -AllowGatewayTransit
```

## 🌐 IP Address Planning

### Hub Network (10.10.0.0/20)
- Total: 4,096 IP addresses
- Subnets:
  - Management: 10.10.0.0/24 (256 IPs)
  - Private Endpoints: 10.10.1.0/24 (256 IPs)
  - Azure Firewall: 10.10.2.0/26 (64 IPs)
  - Gateway: 10.10.3.0/27 (32 IPs)
  - Reserved: 10.10.4.0 - 10.10.15.255 (future expansion)

### W365 Spoke Network (192.168.{N}.0/24) where N=student number
- Total: 256 IP addresses per student
- Subnets (example for Student 1):
  - Cloud PC: 192.168.1.0/26 (64 IPs, 62 usable)
  - Management: 192.168.1.64/26 (64 IPs, 62 usable)
  - AVD: 192.168.1.128/26 (64 IPs, 62 usable)
  - Reserved: 192.168.1.192/26 (64 IPs for expansion)

### Adding More Student Spokes

Each student gets unique Class C range:
- Student 1: 192.168.1.0/24 → `rg-w365-spoke-student1-prod`
- Student 2: 192.168.2.0/24 → `rg-w365-spoke-student2-prod`
- Student 3: 192.168.3.0/24 → `rg-w365-spoke-student3-prod`
- ...
- Student 40: 192.168.40.0/24 → `rg-w365-spoke-student40-prod`

## 🔒 Security Comparison

### Hub Network Security
- ✅ Azure Firewall (optional) for traffic inspection
- ✅ Centralized NSGs for management and private endpoints
- ✅ Private DNS zones for Azure services
- ✅ Diagnostic logging to Log Analytics
- ✅ Subscription-level policies

### W365 Spoke Security
- ✅ Dedicated NSGs for Cloud PC subnet
- ✅ RDP restricted to VirtualNetwork
- ✅ Service endpoints (Storage, KeyVault)
- ✅ Isolated address space
- ✅ Optional connection to hub firewall

## 💰 Cost Comparison

### Hub Network (Estimated Monthly)
- Resource Groups: Free
- Virtual Network: Free
- NSGs: Free
- Private DNS Zones: ~$0.50/zone
- Log Analytics: Pay-as-you-go (~$2-10/GB)
- **Azure Firewall Basic**: ~$90-150/month (if enabled)

### W365 Spoke Network (Estimated Monthly)
- Resource Groups: Free
- Virtual Network: Free
- NSGs: Free
- VNet Peering: ~$0.01/GB ingress + $0.01/GB egress
- **Total**: ~$5-20/month (mainly peering data transfer)

💡 **Tip**: Spoke is significantly cheaper as it leverages hub's shared services!

## 📝 Deployment Checklist

### Deploying Both Hub and Spoke

- [ ] Deploy Hub network first
- [ ] Note Hub VNet resource ID
- [ ] Deploy W365 spoke network
- [ ] Configure spoke-to-hub peering (in spoke parameters)
- [ ] Configure hub-to-spoke peering (manually in hub)
- [ ] Verify bidirectional connectivity
- [ ] Test DNS resolution
- [ ] Deploy Windows 365 Cloud PCs
- [ ] Enable monitoring and alerts

## 🎓 Best Practices

1. **Deploy Hub First**: Always deploy central hub before spokes
2. **Document IP Ranges**: Maintain IP address allocation spreadsheet
3. **Use Consistent Naming**: Follow naming conventions across hub and spokes
4. **Centralize Logging**: Send all logs to hub's Log Analytics workspace
5. **Implement RBAC**: Use separate resource groups for granular permissions
6. **Tag Resources**: Use consistent tagging strategy (env, owner, costCenter)
7. **Version Control**: Keep all Bicep templates in Git
8. **Test in Dev**: Deploy to dev/test environments before production

## 🔄 Migration Scenarios

### Scenario 1: Adding Spoke to Existing Hub
1. Deploy spoke with `hubVnetId` parameter
2. Create reverse peering from hub
3. Update hub firewall rules (if applicable)

### Scenario 2: Starting Fresh
1. Deploy hub with all shared services
2. Deploy one or more spokes
3. Configure peerings
4. Deploy workloads

### Scenario 3: Converting Standalone VNet to Spoke
1. Deploy new spoke with hub integration
2. Migrate resources to new spoke
3. Decommission old standalone VNet

## 📞 Support

For architecture questions:
- Review Azure Well-Architected Framework
- Consult Azure landing zone documentation
- See Microsoft's hub-spoke reference architecture

For deployment issues:
- **Hub**: See `Hub/Deployps1-Readme.md`
- **Spoke**: See `W365/Deployps1-Readme.md`

---

**Need both?** Deploy Hub first, then Spoke! 🚀
