# Azure PowerShell Deployment Script

This PowerShell script provides a reliable alternative to the Azure CLI batch script for deploying the Hub Landing Zone infrastructure. It includes automatic Bicep compilation and comprehensive error handling.

## Prerequisites

1. **Azure PowerShell Module**
   ```powershell
   Install-Module -Name Az -Repository PSGallery -Force -AllowClobber
   ```

2. **Bicep CLI** (automatically checked)
   ```powershell
   # Option 1: Via Azure CLI (recommended)
   az bicep install
   
   # Option 2: Manual install
   # Download from https://github.com/Azure/bicep/releases
   ```

3. **Azure Subscription**
   - Active Azure subscription with appropriate permissions
   - **Owner or Contributor role** at subscription level (required for subscription-level deployments)
   - Permissions needed: `Microsoft.Resources/deployments/validate/action`
   - **Network Contributor role** (optional, only if enabling Azure Firewall)
   - Additional permission for firewall: `Microsoft.Network/virtualNetworks/subnets/join/action`

## Usage

### Basic Deployment

Deploy the infrastructure:
```powershell
.\deploy.ps1
```

### Validation Only

Validate the template without deploying:
```powershell
.\deploy.ps1 -Validate
```

### What-If Analysis

Preview changes before deployment:
```powershell
.\deploy.ps1 -WhatIf
```

### Custom Location

Deploy to a different region:
```powershell
.\deploy.ps1 -Location "canadacentral"
```

### Multi-Tenant Deployment

For administrators with guest access to multiple Azure AD tenants:

#### Interactive Tenant Selection
```powershell
# Script will list all available tenants and prompt for selection
.\deploy.ps1
```

#### Explicit Tenant Selection
```powershell
# Specify tenant ID directly
.\deploy.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

#### Tenant and Subscription Selection
```powershell
# Specify both tenant and subscription for non-interactive automation
.\deploy.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -SubscriptionId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
```

### Enable Azure Firewall (Optional)

By default, Azure Firewall is **disabled** to avoid permission issues. To enable it:

1. **Grant Network Contributor Role**:
   ```powershell
   # Replace with your user principal ID or service principal
   New-AzRoleAssignment `
     -ObjectId "YOUR-OBJECT-ID" `
     -RoleDefinitionName "Network Contributor" `
     -Scope "/subscriptions/YOUR-SUBSCRIPTION-ID"
   ```

2. **Update parameters file** (`parameters.prod.json`):
   ```json
   "enableFirewall": { "value": true }
   ```

3. **Deploy**:
   ```powershell
   .\deploy.ps1
   ```

**Required Permission**: `Microsoft.Network/virtualNetworks/subnets/join/action`

> ⚠️ **Note**: Without Network Contributor role, firewall deployment will fail with `LinkedAccessCheckFailed` error.

## Features

✅ **Automatic Module Check** - Verifies Az PowerShell module is installed  
✅ **Bicep Build Integration** - Automatically compiles .bicep to ARM JSON  
✅ **Login Verification** - Checks Azure login status and prompts if needed  
✅ **Multi-Tenant Support** - Discovers and allows selection from all accessible tenants  
✅ **Tenant Selection** - Interactive tenant picker or explicit `-TenantId` parameter  
✅ **Subscription Selection** - Interactive subscription picker if multiple subscriptions  
✅ **Context Validation** - Confirms correct tenant/subscription before deployment  
✅ **File Validation** - Ensures template and parameter files exist  
✅ **Pre-Deployment Validation** - Tests template before actual deployment  
✅ **Detailed Output** - Shows deployment progress and results  
✅ **Error Handling** - Comprehensive error messages with stack traces  
✅ **Timestamped Names** - Unique deployment names for tracking  
✅ **Location Validation** - Ensures Azure region names are properly formatted

## Advantages over Azure CLI

- **More Reliable**: PowerShell cmdlets have better error handling than CLI
- **Better Output**: Structured output with deployment details
- **Native Windows**: Integrates better with Windows environments
- **Object-Based**: Returns PowerShell objects for further automation
- **No Token Issues**: Avoids "content already consumed" Azure CLI bugs
- **Bicep Integration**: Automatically compiles Bicep to ARM JSON
- **Better Error Messages**: Clearer authorization and validation errors

## Script Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-WhatIf` | Switch | `$false` | Preview changes without deploying |
| `-Validate` | Switch | `$false` | Validate template only |
| `-Location` | String | `"westus3"` | Azure region for deployment |
| `-TenantId` | String | `""` | Azure AD tenant ID to target (optional) |
| `-SubscriptionId` | String | `""` | Azure subscription ID to use (optional) |

## Deployment Components

### Always Deployed (Core Infrastructure)

✅ **Resource Groups**
- `rg-hub-net` - Networking resources
- `rg-hub-ops` - Operations and monitoring

✅ **Networking**
- Virtual Network (VNet) with configurable address space
- Management subnet
- Private endpoints subnet
- Network Security Groups (NSGs)

✅ **Monitoring**
- Log Analytics Workspace
- Diagnostic settings for subscription

✅ **Private DNS**
- Azure service private DNS zones
- VNet links for name resolution

### Conditionally Deployed (Optional)

⚙️ **Azure Firewall** (Default: **DISABLED**)
- **Parameter**: `enableFirewall` in `parameters.prod.json`
- **Default Value**: `false`
- **Required Permission**: Network Contributor role
- **Specific Action**: `Microsoft.Network/virtualNetworks/subnets/join/action`
- **Error if Missing**: `LinkedAccessCheckFailed`
- **How to Enable**: See "Enable Azure Firewall" section above

⚙️ **Budget Monitoring** (Default: **DISABLED**)
- **Parameter**: `budgetContactEmails` in `parameters.prod.json`
- **Default Value**: `[]` (empty array)
- **Required**: At least one email address
- **Error if Missing**: `Notification cannot have all of Contact Emails, Contact Roles and Contact Groups empty`
- **How to Enable**: Add email addresses to `budgetContactEmails` parameter

⚙️ **Location Policy** (Default: **DISABLED**)
- **Parameter**: `enableLocationPolicy` in `policy/main.bicep`
- **Default Value**: `false`
- **Required**: Built-in policy definition must exist in subscription
- **Error if Missing**: `PolicyDefinitionNotFound`
- **How to Enable**: Set `enableLocationPolicy: true` in main.bicep

⚙️ **RBAC Assignments** (Optional)
- **Parameters**: `networkAdminsGroupObjectId`, `opsGroupObjectId`
- **Default Value**: `""` (empty string - RBAC skipped)
- **Required**: Valid Azure AD group object IDs
- **How to Enable**: Provide group object IDs in parameters file

## Examples

### Example 1: Full Deployment
```powershell
# Deploy everything
.\deploy.ps1
```

### Example 2: Pre-Flight Check
```powershell
# Validate first
.\deploy.ps1 -Validate

# Review changes
.\deploy.ps1 -WhatIf

# Deploy if satisfied
.\deploy.ps1
```

### Example 3: Canada Deployment
```powershell
.\deploy.ps1 -Location "canadacentral"
```

### Example 4: Multi-Tenant Interactive Deployment
```powershell
# Script will discover available tenants and prompt for selection
.\deploy.ps1

# Output example:
# Available Tenants:
#   [1] Contoso (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
#   [2] Fabrikam (yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy)
# Select tenant number (1-2): 2
```

### Example 5: Automated Multi-Tenant Deployment
```powershell
# For automation scripts - specify tenant and subscription explicitly
$tenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$subscriptionId = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"

.\deploy.ps1 -TenantId $tenantId -SubscriptionId $subscriptionId
```

### Example 6: Guest User Deployment
```powershell
# When you are a guest user in a customer's tenant
# First, list available tenants interactively
.\deploy.ps1 -Validate

# Then deploy to the correct tenant
.\deploy.ps1 -TenantId "customer-tenant-id"
```

## Troubleshooting

### Common Deployment Errors

#### 1. Location Format Error
**Error**: `The specified location 'canada-central' is invalid`

**Solution**: Azure region names must not contain hyphens. Use:
- ✅ `canadacentral` (correct)
- ❌ `canada-central` (incorrect)

Update `parameters.prod.json`:
```json
"location": { "value": "canadacentral" }
```

#### 2. Tenant Authentication Required (MFA)
**Error**: `Authentication failed against tenant. User interaction is required. This may be due to the conditional access policy settings such as multi-factor authentication (MFA).`

**Cause**: The tenant requires additional authentication (MFA or conditional access) before you can access its subscriptions.

**Solution**: Authenticate specifically to that tenant before running the deployment:
```powershell
# Step 1: Authenticate to the specific tenant
Connect-AzAccount -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Step 2: Run deployment with explicit tenant ID
.\deploy.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**Alternative**: If you see multiple tenants but one fails authentication, select a different tenant that you have proper access to.

#### 3. Budget Notification Error
**Error**: `Notification cannot have all of Contact Emails, Contact Roles and Contact Groups empty`

**Solution**: The budget module is now disabled by default. To enable:
```json
"budgetContactEmails": { "value": ["your.email@domain.com"] }
```

#### 4. Policy Definition Not Found
**Error**: `PolicyDefinitionNotFound: e56962a6-4747-49cd-b67b-bf8b01975c4c`

**Solution**: The policy module is now disabled by default. It will be skipped during deployment.

#### 5. Azure Firewall Permission Error
**Error**: `LinkedAccessCheckFailed: does not have authorization to perform action 'Microsoft.Network/virtualNetworks/subnets/join/action'`

**Cause**: Azure Firewall deployment requires Network Contributor role

**Solution**: Either disable the firewall (default) or grant permissions:

**Option A: Keep Firewall Disabled (Recommended for initial deployment)**
```json
// parameters.prod.json
"enableFirewall": { "value": false }
```

**Option B: Grant Network Contributor Role**
```powershell
# Get your user object ID
$userId = (Get-AzADUser -UserPrincipalName "your.email@domain.com").Id

# Assign Network Contributor role
New-AzRoleAssignment `
  -ObjectId $userId `
  -RoleDefinitionName "Network Contributor" `
  -Scope "/subscriptions/YOUR-SUBSCRIPTION-ID"

# Then enable firewall in parameters.prod.json
"enableFirewall": { "value": true }
```

**Required Permissions for Firewall**:
- Role: Network Contributor (or custom role with below actions)
- Actions:
  - `Microsoft.Network/virtualNetworks/subnets/join/action`
  - `Microsoft.Network/azureFirewalls/write`
  - `Microsoft.Network/azureFirewalls/read`

#### 6. Authorization Failed
**Error**: `AuthorizationFailed: does not have authorization to perform action 'Microsoft.Resources/deployments/validate/action'`

**Solution**: Request **Owner** or **Contributor** role at subscription level:
```powershell
# Check current role assignments
az role assignment list --assignee your.email@domain.com --subscription YOUR-SUB-ID --output table
```

### Module Not Found
```powershell
Install-Module -Name Az -Repository PSGallery -Force
Import-Module Az
```

### Login Issues
```powershell
Connect-AzAccount
Get-AzContext
```

### Clear Cached Credentials
```powershell
Disconnect-AzAccount
Clear-AzContext -Force
Connect-AzAccount
```

### Check Subscription
```powershell
Get-AzSubscription
Set-AzContext -Subscription "Your-Subscription-Name"
```

### Bicep Build Issues
```powershell
# Check Bicep version
az bicep version

# Update Bicep
az bicep upgrade

# Manual build
az bicep build --file infra/envs/prod/main.bicep
```

### Template Validation Failed
```powershell
# Run validation only
.\deploy.ps1 -Validate

# Check specific errors
Test-AzSubscriptionDeployment `
  -Location "canadacentral" `
  -TemplateFile "infra/envs/prod/main.json" `
  -TemplateParameterFile "infra/envs/prod/parameters.prod.json"
```

## Files Used

- `infra/envs/prod/main.bicep` - Main Bicep template (auto-compiled to JSON)
- `infra/envs/prod/main.json` - Compiled ARM template (auto-generated)
- `infra/envs/prod/parameters.prod.json` - Parameter values
- `deploy.ps1` - This PowerShell script

## Deployment Process

The script follows these steps:

1. ✅ **Check Prerequisites**
   - Verify Az PowerShell module installed
   - Check Bicep CLI availability

2. ✅ **Azure Login & Context Selection**
   - Verify authenticated session
   - Prompt login if needed
   - Discover all accessible tenants
   - Select tenant (interactive or via parameter)
   - List subscriptions in selected tenant
   - Select subscription (interactive or via parameter)
   - Establish Azure context with correct tenant/subscription
   - Display active context confirmation

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

## Output

The script provides:
- Deployment name and timestamp
- Provisioning state
- Output values (e.g., VNet ID, resource IDs)
- Detailed error messages if deployment fails

## Exit Codes

- `0` - Success
- `1` - Failure (check error output)

## Notes

- Deployment names are automatically timestamped: `hub-deploy-YYYYMMDD-HHmmss`
- The script discovers all tenants accessible to the signed-in user
- For multi-tenant scenarios, administrators can select the target tenant interactively
- Use `-TenantId` and `-SubscriptionId` parameters for non-interactive automation
- The script establishes the correct Azure context before deployment
- Bicep is automatically compiled to ARM JSON before deployment
- Template validation runs before actual deployment
- Budget and Policy modules are **disabled by default** (conditional deployment)
- Location must use Azure's no-hyphen format (e.g., `canadacentral`, not `canada-central`)
- Use `-Verbose` for even more detailed output if needed
- Log files are stored in Azure deployment history

## Known Issues & Fixes

### ✅ Fixed in Current Version

1. **Azure Firewall SKU Error** - Fixed placement of `sku` property in Bicep template
2. **Location Format** - Changed from `canada-central` to `canadacentral` format
3. **Budget Notifications** - Now conditionally deployed (disabled by default)
4. **Policy Definition** - Now conditionally deployed (disabled by default)
5. **Azure CLI Token Bug** - Replaced with PowerShell implementation
6. **Azure Firewall Permissions** - Now conditionally deployed (disabled by default)

### 🔐 Required Permissions Summary

| Component | Default | Role Required | Specific Action |
|-----------|---------|---------------|-----------------|
| **Core Deployment** | ✅ Enabled | Owner or Contributor | `Microsoft.Resources/deployments/validate/action` |
| **Azure Firewall** | ❌ Disabled | Network Contributor | `Microsoft.Network/virtualNetworks/subnets/join/action` |
| **Budget Alerts** | ❌ Disabled | Contributor | N/A (just need contact emails) |
| **Policy Assignment** | ❌ Disabled | Contributor | Built-in policy must exist |
| **RBAC Assignments** | ❌ Disabled | Owner or User Access Administrator | AAD group object IDs required |

### 📋 Pre-Deployment Checklist

Before running `.\deploy.ps1`:

- [ ] Azure PowerShell Az module installed
- [ ] Bicep CLI installed (`az bicep version`)
- [ ] Logged into Azure (`Connect-AzAccount`)
- [ ] Contributor or Owner role on target subscription
- [ ] Location format uses no hyphens (e.g., `canadacentral`)
- [ ] Optional: Network Contributor role (if enabling firewall)
- [ ] Optional: Budget contact emails configured
- [ ] Optional: AAD group object IDs for RBAC

## Support

For issues:
1. Check the error message in red text
2. Review Azure Portal → Deployments for details
3. Verify permissions on the subscription
4. Ensure all Bicep files are valid

---

**Tip**: Always run `-Validate` or `-WhatIf` before your first deployment!
