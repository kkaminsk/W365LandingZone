# Windows 365 Permissions Module

## Overview

This Bicep module configures the required Azure RBAC permissions for Windows 365 Cloud PC provisioning. The Windows 365 service requires specific permissions on your Azure networking resources to successfully provision and manage Cloud PCs.

## Required Permissions

The module assigns two critical roles to the Windows 365 service principal:

### 1. Windows 365 Network Interface Contributor
- **Scope**: Resource Group
- **Role Definition ID**: `1f135831-5de7-4ab3-a68b-e0926a04114a`
- **Purpose**: Allows Windows 365 to create and manage network interfaces for Cloud PCs

### 2. Windows 365 Network User
- **Scope**: Virtual Network
- **Role Definition ID**: `7e5e59c4-06c5-4b8c-a3f9-2f3d8e1c5b9a`
- **Purpose**: Allows Windows 365 to use the virtual network for Cloud PC connectivity

## Windows 365 Service Principal

The Windows 365 service principal is automatically created in your tenant when you have Windows 365 licenses:

- **Application ID**: `0af06dc6-e4b5-4f28-818e-e78e62d137a5` (constant across all tenants)
- **Display Name**: "Windows 365"
- **Object ID**: Retrieved dynamically at deployment time (varies by tenant)

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `resourceGroupName` | string | Name of the resource group where role assignments are created |
| `vnetName` | string | Name of the virtual network for Network User role assignment |
| `windows365ServicePrincipalId` | string | Object ID of the Windows 365 service principal (retrieved dynamically) |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `rgRoleAssignmentId` | string | Resource ID of the resource group role assignment |
| `vnetRoleAssignmentId` | string | Resource ID of the virtual network role assignment |
| `status` | string | Confirmation message |

## Deployment

This module is automatically deployed as part of the main W365 deployment. The deployment script (`deploy.ps1`) retrieves the Windows 365 service principal Object ID at runtime and passes it to the Bicep template.

### Manual Deployment Example

```bicep
module w365Permissions './w365-permissions/main.bicep' = {
  name: 'w365-permissions'
  scope: resourceGroup('rg-w365-spoke-student1-prod')
  params: {
    resourceGroupName: 'rg-w365-spoke-student1-prod'
    vnetName: 'vnet-w365-spoke-student1-prod'
    windows365ServicePrincipalId: '<object-id-of-w365-sp>'
  }
}
```

## Verification

After deployment, you can verify the permissions using the `Check-W365Permissions.ps1` script:

```powershell
.\Check-W365Permissions.ps1
```

The script will check:
1. ✅ Reader role on subscription (optional, but recommended)
2. ✅ Windows 365 Network Interface Contributor on resource group
3. ✅ Windows 365 Network User on virtual network

## Troubleshooting

### Error: "Windows 365 service principal not found"

**Cause**: Your tenant doesn't have the Windows 365 service principal (usually because no Windows 365 licenses are assigned)

**Solution**: 
1. Ensure Windows 365 licenses are purchased and assigned in your tenant
2. The service principal should appear automatically

### Error: "Insufficient privileges to complete the operation"

**Cause**: The account running the deployment doesn't have permission to assign roles

**Solution**: Ensure you have one of these roles:
- **Owner** on the subscription
- **User Access Administrator** on the subscription
- **Contributor** + **User Access Administrator** on the resource group

## References

- [Windows 365 network requirements](https://learn.microsoft.com/en-us/windows-365/enterprise/requirements-network)
- [Azure built-in roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Windows 365 service principal permissions](https://learn.microsoft.com/en-us/windows-365/enterprise/azure-network-connections)

## Notes

- Role assignments use GUID-based names to ensure idempotency
- The module can be safely rerun - existing role assignments will not be duplicated
- Permissions are required before creating Windows 365 provisioning policies
