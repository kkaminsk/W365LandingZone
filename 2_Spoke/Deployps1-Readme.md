# Windows 365 Spoke Network - PowerShell Deployment Guide

This PowerShell script deploys a Windows 365 spoke network infrastructure to Azure using Bicep templates. The deployment creates a dedicated virtual network optimized for Windows 365 Cloud PCs with proper segmentation and security controls.

## 🎯 What Gets Deployed

### Always Deployed (Core Infrastructure)

✅ **Resource Group**
- `rg-w365-spoke-student{N}-prod` - Contains all Windows 365 spoke network resources (where {N} = student number)

✅ **Virtual Network**
- **Address Space**: `192.168.{N}.0/24` (where {N} = student number 1-40)
- **Name**: `vnet-w365-spoke-student{N}-prod`
- **Location**: southcentralus (configurable)

✅ **Subnets** (Example for Student 1)
- **Cloud PC Subnet** (`192.168.1.0/26`) - 62 usable IPs for Windows 365 Cloud PCs
- **Management Subnet** (`192.168.1.64/26`) - 62 usable IPs for management resources
- **AVD Subnet** (`192.168.1.128/26`) - 62 usable IPs (optional, disabled by default)

✅ **Network Security Groups (NSGs)**
- **Cloud PC NSG** - Windows 365 specific security rules
  - Allow RDP (3389) from VirtualNetwork
  - Allow HTTPS (443) outbound for Windows 365 service
  - Allow DNS (53) outbound
- **Management NSG** - Management traffic controls
  - Allow HTTPS (443) for management
- **AVD NSG** - Azure Virtual Desktop rules (if AVD subnet enabled)

✅ **Service Endpoints**
- Microsoft.Storage (for profile containers)
- Microsoft.KeyVault (for secrets management)

### Optionally Deployed

⚙️ **VNet Peering to Hub** (Default: **DISABLED**)
- **Parameter**: `hubVnetId` in `parameters.prod.json`
- **Default Value**: `""` (empty string - no peering)
- **Required**: Hub VNet resource ID
- **How to Enable**: Provide hub VNet ID in parameters file

⚙️ **Azure Virtual Desktop Subnet** (Default: **DISABLED**)
- **Parameter**: `enableAvdSubnet` in `parameters.prod.json`
- **Default Value**: `false`
- **How to Enable**: Set to `true` in parameters file

## 📋 Prerequisites

### 1. Software Requirements

**PowerShell Modules**
```powershell
# RECOMMENDED: Install all required modules at once
cd ..
cd InstallStudentModules
.\InstallStudentModules.ps1

# OR install manually:
Install-Module -Name Az -Repository PSGallery -Force -AllowClobber
Install-Module -Name Microsoft.Graph -Repository PSGallery -Force

# Verify installation
Get-Module -ListAvailable -Name Az
```

**Bicep CLI** (required)
```powershell
# Install via winget (recommended)
winget install -e --id Microsoft.Bicep

# Verify Bicep version
bicep --version

# Alternative: Download from https://aka.ms/bicep-install
```

### 2. Azure Permissions

#### Minimum Required Permissions

You need **ONE** of the following permission sets:

**Option A: Contributor Role** (Recommended)
```powershell
# Contributor role at subscription level
Role: Contributor
Scope: /subscriptions/{subscription-id}
```

**Option B: Network Contributor + Resource Group Contributor**
```powershell
# Network Contributor for networking resources
Role: Network Contributor
Scope: /subscriptions/{subscription-id}

# AND permission to create resource groups
Action: Microsoft.Resources/subscriptions/resourceGroups/write
Scope: /subscriptions/{subscription-id}
```

#### Specific Actions Required

| Action | Purpose | Required |
|--------|---------|----------|
| `Microsoft.Resources/subscriptions/resourceGroups/write` | Create resource group | ✅ Yes |
| `Microsoft.Network/virtualNetworks/write` | Create VNet | ✅ Yes |
| `Microsoft.Network/virtualNetworks/subnets/write` | Create subnets | ✅ Yes |
| `Microsoft.Network/networkSecurityGroups/write` | Create NSGs | ✅ Yes |
| `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write` | Create VNet peering | ⚙️ If peering to hub |
| `Microsoft.Resources/deployments/validate/action` | Validate template | ✅ Yes |

### 3. Azure Subscription

- Active Azure subscription
- Sufficient quota for:
  - 1 Resource Group
  - 1 Virtual Network
  - 2-3 Subnets
  - 2-3 Network Security Groups
  - 1 VNet Peering (if connecting to hub)

## 🚀 Usage

### Basic Deployment

Deploy the Windows 365 spoke network for student 1:
```powershell
cd W365
.\deploy.ps1 -StudentNumber 1
```

### Deploy for Different Students

Deploy for student 5 (gets 192.168.5.0/24):
```powershell
.\deploy.ps1 -StudentNumber 5
```

### Validation Only

Validate the template without deploying:
```powershell
.\deploy.ps1 -Validate -StudentNumber 1
```

### What-If Analysis

Preview changes before deployment:
```powershell
.\deploy.ps1 -WhatIf -StudentNumber 1
```

### Custom Location

Deploy to a different region:
```powershell
.\deploy.ps1 -Location "eastus" -StudentNumber 1
```

### Cross-Subscription Deployment (Hub & Spoke Separation)

If your Hub network is in one subscription and you want to deploy the Spoke to a **different** subscription:
```powershell
# Deploy Spoke to a specific subscription ID
.\deploy.ps1 -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -StudentNumber 1
```

The script will handle the context switching. The optional peering to the Hub (via `hubVnetId` parameter) supports cross-subscription links natively.

### Multi-Tenant Administration

If you have access to multiple Azure AD tenants, the script now guides you through choosing the correct tenant and subscription before validation or deployment.

**Interactive selection**
```powershell
.\deploy.ps1
# The script lists available tenants and subscriptions and prompts for your choice.
```

**Explicit parameters for automation**
```powershell
.\deploy.ps1 -TenantId "<tenant-guid>" -SubscriptionId "<subscription-guid>"
# Skips interactive prompts and validates the supplied IDs before continuing.
```

If a tenant requires additional MFA, run `Connect-AzAccount -TenantId <tenant-guid>` to complete the challenge and then rerun the deployment with the `-TenantId` parameter.

## ⚙️ Configuration

### Basic Configuration

Edit `infra/envs/prod/parameters.prod.json`:

```json
{
  "parameters": {
    "location": { "value": "southcentralus" },
    "env": { "value": "prod" },
    "studentNumber": { "value": 1 }
  }
}
```

> **Note**: IP addresses are calculated automatically from `studentNumber`. Student 1 gets 192.168.1.0/24, Student 5 gets 192.168.5.0/24, etc.

### Enable Hub Peering

To connect this spoke to your hub network:

1. **Get Hub VNet ID**:
   ```powershell
   # From Azure Portal or CLI
   $hubVnetId = "/subscriptions/{sub-id}/resourceGroups/rg-hub-net/providers/Microsoft.Network/virtualNetworks/vnet-hub"
   ```

2. **Update parameters.prod.json**:
   ```json
   {
     "hubVnetId": { 
       "value": "/subscriptions/{sub-id}/resourceGroups/rg-hub-net/providers/Microsoft.Network/virtualNetworks/vnet-hub"
     },
     "allowForwardedTraffic": { "value": true },
     "useRemoteGateways": { "value": false }
   }
   ```

3. **Deploy**:
   ```powershell
   .\deploy.ps1
   ```

4. **Configure Hub-side Peering**:
   ```powershell
   # Must be done separately in the hub network
   # The hub admin needs to create peering from hub to this spoke
   ```

### Enable Azure Virtual Desktop Subnet

If you plan to use AVD alongside Windows 365:

```json
{
  "enableAvdSubnet": { "value": true }
}
```

### Customize Address Space

To use a different Class C range:

```json
{
  "vnetAddressSpace": { "value": "192.168.200.0/24" },
  "cloudPCSubnetPrefix": { "value": "192.168.200.0/26" },
  "mgmtSubnetPrefix": { "value": "192.168.200.64/26" },
  "avdSubnetPrefix": { "value": "192.168.200.128/26" }
}
```

## 🔍 Deployment Process

The script follows these steps:

1. ✅ **Check Prerequisites**
   - Verify Az PowerShell module installed
   - Check Bicep CLI availability

2. ✅ **Azure Login**
   - Verify authenticated session
   - Prompt login if needed
   - Select subscription (if multiple)

3. ✅ **File Validation**
   - Check Bicep template exists
   - Check parameter file exists

4. ✅ **Build Bicep**
   - Compile `.bicep` to ARM `.json`
   - Use `az bicep build` command

5. ✅ **Validate Template**
   - Run `Test-AzSubscriptionDeployment`
   - Catch errors before deployment

6. ✅ **Deploy**
   - Execute `New-AzSubscriptionDeployment`
   - Show progress and results

## 🔧 Troubleshooting

### Common Deployment Errors

#### 1. Location Format Error
**Error**: `The specified location 'canada-central' is invalid`

**Solution**: Azure region names must not contain hyphens. Use:
- ✅ `canadacentral` (correct)
- ❌ `canada-central` (incorrect)

#### 2. Insufficient Permissions
**Error**: `AuthorizationFailed: does not have authorization to perform action 'Microsoft.Network/virtualNetworks/write'`

**Solution**: You need Network Contributor or Contributor role:

```powershell
# Check current role assignments
Get-AzRoleAssignment -SignInName your.email@domain.com

# Request Contributor role from subscription admin
# OR request Network Contributor role:
New-AzRoleAssignment `
  -SignInName "your.email@domain.com" `
  -RoleDefinitionName "Network Contributor" `
  -Scope "/subscriptions/YOUR-SUBSCRIPTION-ID"
```

#### 3. Resource Group Creation Failed
**Error**: `does not have authorization to perform action 'Microsoft.Resources/subscriptions/resourceGroups/write'`

**Solution**: You need permission to create resource groups. Request Contributor role at subscription level.

#### 4. VNet Peering Failed
**Error**: `LinkedAccessCheckFailed: does not have authorization to perform action 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write'`

**Solution**: 
- Ensure you have Network Contributor on both the spoke and hub VNets
- Verify the hub VNet ID is correct
- Check that hub VNet exists and is accessible

#### 5. Address Space Conflict
**Error**: `AddressSpaceIsNotWithinVnetAddressSpace` or `SubnetOverlap`

**Solution**: Ensure your subnets don't overlap and fit within the VNet address space.

Example for Student 1:
```
VNet:     192.168.1.0/24    (256 IPs)
├─ CloudPC:  .0/26          (64 IPs: .0-.63)
├─ Mgmt:     .64/26         (64 IPs: .64-.127)
└─ AVD:      .128/26        (64 IPs: .128-.191)
```

The script automatically calculates these based on the StudentNumber parameter.

### Permission Issues

#### Check Current Permissions
```powershell
# Check your role assignments
Get-AzRoleAssignment -SignInName your.email@domain.com -Scope "/subscriptions/YOUR-SUB-ID"

# Check specific resource group permissions (after RG created)
Get-AzRoleAssignment -ResourceGroupName "rg-w365-spoke-student1-prod"
```

#### Request Permissions
```powershell
# Option 1: Request Contributor role (recommended)
# Contact your subscription administrator

# Option 2: Request Network Contributor
# Contact your subscription administrator
```

### Module Not Found
```powershell
# Install Az module
Install-Module -Name Az -Repository PSGallery -Force
Import-Module Az

# Verify installation
Get-Module -ListAvailable -Name Az
```

### Login Issues
```powershell
# Clear and re-authenticate
Disconnect-AzAccount
Clear-AzContext -Force
Connect-AzAccount
```

### Bicep Build Issues
```powershell
# Check Bicep version
az bicep version

# Update Bicep
az bicep upgrade

# Manual build test
az bicep build --file infra/envs/prod/main.bicep
```

## 📊 Outputs

After successful deployment, you'll receive:

```
Outputs:
  resourceGroupName: rg-w365-spoke-prod
  vnetId: /subscriptions/.../virtualNetworks/vnet-w365-spoke-prod
  vnetName: vnet-w365-spoke-prod
  cloudPCSubnetId: /subscriptions/.../subnets/snet-cloudpc
  mgmtSubnetId: /subscriptions/.../subnets/snet-mgmt
  avdSubnetId: (empty if AVD disabled)
  peeringStatus: Configured / Not Configured
```

## 📁 Files Structure

```
W365/
├── deploy.ps1                          # This deployment script
├── Deployps1-Readme.md                 # This documentation
└── infra/
    ├── modules/
    │   ├── rg/
    │   │   └── main.bicep              # Resource group module
    │   └── spoke-network/
    │       └── main.bicep              # Spoke network module
    └── envs/
        └── prod/
            ├── main.bicep              # Main orchestration template
            ├── main.json               # Compiled ARM template (auto-generated)
            └── parameters.prod.json    # Parameter values
```

## 🔐 Security Considerations

### Network Security Groups

The deployment includes pre-configured NSG rules:

**Cloud PC Subnet NSG**:
- ✅ Allow RDP (3389) from VirtualNetwork
- ✅ Allow HTTPS (443) outbound
- ✅ Allow DNS (53) outbound

**Management Subnet NSG**:
- ✅ Allow HTTPS (443) for management

⚠️ **Important**: Review and customize NSG rules based on your security requirements before production use.

### Service Endpoints

Enabled by default:
- `Microsoft.Storage` - For FSLogix profile containers
- `Microsoft.KeyVault` - For secrets and certificate management

### Best Practices

1. **Always run validation first**: `.\deploy.ps1 -Validate`
2. **Use What-If for changes**: `.\deploy.ps1 -WhatIf`
3. **Review NSG rules** before deployment
4. **Document your IP address scheme**
5. **Use hub-spoke topology** for centralized security
6. **Enable diagnostic logs** (add Log Analytics after deployment)

## 🎓 Next Steps

After deploying the spoke network:

1. **Configure Hub Peering** (if using hub-spoke):
   - Create peering from hub to this spoke
   - Verify bidirectional connectivity

2. **Deploy Windows 365**:
   - Configure Azure AD join
   - Create provisioning policy
   - Assign Cloud PC licenses
   - Deploy Cloud PCs to `snet-cloudpc` subnet

3. **Enable Monitoring**:
   - Configure Network Watcher
   - Enable NSG flow logs
   - Set up Azure Monitor alerts

4. **Security Hardening**:
   - Review and customize NSG rules
   - Implement Conditional Access policies
   - Configure DDoS protection (if required)

## 📞 Support

For issues or questions:

1. Check the **Troubleshooting** section above
2. Review Azure Portal → Deployments for detailed error messages
3. Verify permissions using provided PowerShell commands
4. Check Azure service health for regional issues

## ✅ Pre-Deployment Checklist

Before running `.\deploy.ps1`:

- [ ] Azure PowerShell Az module installed
- [ ] Bicep CLI installed (`az bicep version`)
- [ ] Logged into Azure (`Connect-AzAccount`)
- [ ] **Contributor** or **Network Contributor** role on subscription
- [ ] Permission to create resource groups
- [ ] Location format uses no hyphens (e.g., `canadacentral`)
- [ ] IP address scheme documented and approved
- [ ] Hub VNet ID obtained (if peering required)
- [ ] Parameters file reviewed and customized

## 🔄 Version History

- **v1.0** - Initial release
  - Basic spoke network deployment
  - Windows 365 optimized subnets
  - NSG with Windows 365 rules
  - Optional hub peering
  - Optional AVD subnet

---

**Ready to Deploy?** Run `.\deploy.ps1 -Validate` first to check your configuration! 🚀
