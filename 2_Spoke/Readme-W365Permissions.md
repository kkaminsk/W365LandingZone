# Windows 365 Permission Management Scripts

This repository contains PowerShell scripts for managing and verifying Azure role-based access control (RBAC) permissions required for Windows 365 Cloud PC deployments.

## Overview

Windows 365 requires specific Azure permissions to create and manage Cloud PCs in your Azure Virtual Network. These scripts help you check for and assign the necessary permissions to the Windows 365 Service Principal.

## Scripts

### 1. Check-W365Permissions.ps1
**Purpose**: Non-invasive audit script that checks if the Windows 365 Service Principal has the required permissions.

**What it does**:
- ✅ Connects to your Azure account
- ✅ Lists available subscriptions, resource groups, and virtual networks
- ✅ Checks for three critical role assignments:
  1. **Reader** role at the subscription level
  2. **Windows 365 Network Interface Contributor** role at the resource group level
  3. **Windows 365 Network User** role at the virtual network level
- ✅ Generates a timestamped log file with results

**Use this script when**:
- You want to verify permissions without making changes
- You're troubleshooting Windows 365 deployment issues
- You need to audit existing role assignments

### 2. Set-W365Permissions.ps1
**Purpose**: Invasive script that automatically assigns missing Windows 365 permissions.

**What it does**:
- ⚠️ Connects to your Azure account (requires elevated permissions)
- ⚠️ Checks for missing role assignments
- ⚠️ **Automatically assigns** the following roles if missing:
  1. **Reader** role at the subscription level
  2. **Windows 365 Network Interface Contributor** role at the resource group level
  3. **Windows 365 Network User** role at the virtual network level
- ✅ Skips roles that are already assigned
- ✅ Provides detailed error messages if assignments fail
- ✅ Generates a timestamped log file with all actions

**Use this script when**:
- You need to quickly configure Windows 365 permissions
- You have the necessary Azure permissions to assign roles
- You want to automate permission setup

## Prerequisites

### Required PowerShell Modules
```powershell
# Install the Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force -AllowClobber
```

### Required Azure Permissions

#### For Check-W365Permissions.ps1:
- **Reader** access to the subscription, resource group, and virtual network
- Permission to view role assignments (e.g., `Microsoft.Authorization/roleAssignments/read`)

#### For Set-W365Permissions.ps1:
- **Owner** or **User Access Administrator** role at the subscription level, OR
- **Owner** or **User Access Administrator** role at the resource group and virtual network level

### Windows 365 Service Principal
Both scripts require the Windows 365 Service Principal to exist in your Azure AD tenant:
- **Application ID**: `0af06dc6-e4b5-4f28-818e-e78e62d137a5`
- **Display Name**: Windows 365

This service principal is automatically created when you enable Windows 365 in your Microsoft 365 tenant.

## Usage

### Step 1: Check Current Permissions

```powershell
# Navigate to the script directory
cd "C:\Path\To\W365"

# Run the check script
.\Check-W365Permissions.ps1
```

**Example Output**:
```
🔍 1. Checking Subscription-Level Permissions...
  ❌ Failed: Did not find 'Reader' role on the subscription.

🔍 2. Checking Resource Group-Level Permissions...
  ❌ Failed: Did not find 'Windows 365 Network Interface Contributor' role on the resource group.

🔍 3. Checking Virtual Network-Level Permissions...
  ❌ Failed: Did not find 'Windows 365 Network User' role on the virtual network.
```

### Step 2: Assign Missing Permissions

If permissions are missing, run the assignment script:

```powershell
# Run the set script (requires elevated permissions)
.\Set-W365Permissions.ps1
```

**Example Output**:
```
🔍 1. Checking Subscription-Level 'Reader' Permission...
  ⚠️  Missing: 'Reader' role on the subscription. Attempting to assign...
  ✅ SUCCESS: Assigned 'Reader' role on the subscription.

🔍 2. Checking Resource Group-Level 'Windows 365 Network Interface Contributor' Permission...
  ⚠️  Missing: 'Windows 365 Network Interface Contributor' role on the resource group. Attempting to assign...
  ✅ SUCCESS: Assigned 'Windows 365 Network Interface Contributor' role on the resource group.

🔍 3. Checking Virtual Network-Level 'Windows 365 Network User' Permission...
  ⚠️  Missing: 'Windows 365 Network User' role on the virtual network. Attempting to assign...
  ✅ SUCCESS: Assigned 'Windows 365 Network User' role on the virtual network.
```

### Step 3: Verify Permissions

Run the check script again to confirm all permissions are in place:

```powershell
.\Check-W365Permissions.ps1
```

**Expected Output**:
```
🔍 1. Checking Subscription-Level Permissions...
  ✅ Success: Found 'Reader' role on the subscription.

🔍 2. Checking Resource Group-Level Permissions...
  ✅ Success: Found 'Windows 365 Network Interface Contributor' role on the resource group.

🔍 3. Checking Virtual Network-Level Permissions...
  ✅ Success: Found 'Windows 365 Network User' role on the virtual network.
```

## Workflow Diagram

```
┌─────────────────────────────────────┐
│ Start: Need to deploy Windows 365  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Run: Check-W365Permissions.ps1      │
│ Purpose: Audit existing permissions │
└──────────────┬──────────────────────┘
               │
               ▼
        ┌──────┴──────┐
        │ All ✅ ?    │
        └──────┬──────┘
        YES ◄──┴──► NO
         │           │
         │           ▼
         │  ┌─────────────────────────────────────┐
         │  │ Run: Set-W365Permissions.ps1        │
         │  │ Purpose: Assign missing permissions │
         │  └──────────────┬──────────────────────┘
         │                 │
         │                 ▼
         │  ┌─────────────────────────────────────┐
         │  │ Run: Check-W365Permissions.ps1      │
         │  │ Purpose: Verify assignments         │
         │  └──────────────┬──────────────────────┘
         │                 │
         └─────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│ Ready to deploy Windows 365 Cloud  │
│ PCs in your Azure Virtual Network  │
└─────────────────────────────────────┘
```

## Log Files

Both scripts generate timestamped log files in your Documents folder:

- **Check script**: `C:\Users\<YourUsername>\Documents\Check-W365Permissions-MM-dd-HH-mm.log`
- **Set script**: `C:\Users\<YourUsername>\Documents\Set-W365Permissions-MM-dd-HH-mm.log`

Log files contain:
- Timestamp for each action
- User selections (subscription, resource group, virtual network)
- Permission check results
- Assignment actions and results
- Error messages (if any)

## Required Azure Roles

### 1. Reader (Subscription Level)
- **Scope**: `/subscriptions/{subscription-id}`
- **Purpose**: Allows Windows 365 to read subscription information and resources
- **Permissions**: Read-only access to all resources in the subscription

### 2. Windows 365 Network Interface Contributor (Resource Group Level)
- **Scope**: `/subscriptions/{subscription-id}/resourceGroups/{resource-group-name}`
- **Purpose**: Allows Windows 365 to create and manage network interfaces for Cloud PCs
- **Permissions**: Create, update, and delete network interfaces in the resource group

### 3. Windows 365 Network User (Virtual Network Level)
- **Scope**: `/subscriptions/{subscription-id}/resourceGroups/{resource-group-name}/providers/Microsoft.Network/virtualNetworks/{vnet-name}`
- **Purpose**: Allows Windows 365 to join Cloud PCs to the specified virtual network
- **Permissions**: Read virtual network and join network interfaces to subnets

## Troubleshooting

### Error: "Could not find the Windows 365 Service Principal"
**Cause**: The Windows 365 service is not enabled in your tenant, or the service principal doesn't exist.

**Solution**: 
1. Ensure you have a Windows 365 license in your Microsoft 365 tenant
2. Visit the Windows 365 admin portal to activate the service
3. The service principal will be automatically created

### Error: "Failed to assign role"
**Cause**: You don't have sufficient permissions to assign roles.

**Solution**: 
1. Request **Owner** or **User Access Administrator** role from your Azure administrator
2. Alternatively, ask someone with appropriate permissions to run the `Set-W365Permissions.ps1` script

### Warning: "Authentication failed against tenant"
**Cause**: Your account has access to multiple Azure AD tenants.

**Solution**: 
1. The script will prompt you to select the correct tenant
2. Choose the tenant where your Windows 365 subscription exists

### Error: "No virtual networks found"
**Cause**: The selected resource group doesn't contain any virtual networks.

**Solution**: 
1. Select a different resource group that contains your Windows 365 virtual network
2. Create a virtual network if one doesn't exist

## Security Best Practices

1. **Principle of Least Privilege**: Only assign the minimum required permissions
2. **Review Regularly**: Periodically audit role assignments using the check script
3. **Log Retention**: Keep log files for audit and compliance purposes
4. **Role Separation**: Use separate accounts for read-only checks vs. permission assignments
5. **Automation**: Consider using Azure Policy or infrastructure-as-code tools for production environments

## Additional Resources

- [Windows 365 Network Requirements](https://learn.microsoft.com/en-us/windows-365/enterprise/requirements-network)
- [Azure RBAC Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/)
- [Windows 365 Enterprise Planning Guide](https://learn.microsoft.com/en-us/windows-365/enterprise/planning-guide)

## Support

For issues or questions:
1. Check the log files in your Documents folder
2. Review the error messages in the script output
3. Consult the Windows 365 documentation
4. Contact your Azure administrator for permission-related issues

---

**Last Updated**: October 2025  
**Version**: 1.0  
**Tested On**: Azure PowerShell Az module 11.x+
