@description('Resource Group name where the role assignments will be created')
param resourceGroupName string

@description('Virtual Network name for Windows 365 Network User role')
param vnetName string

@description('Windows 365 Service Principal Object ID - must be retrieved at deployment time')
param windows365ServicePrincipalId string

// Built-in role definition IDs (these are constant across all Azure tenants)
var windows365NetworkInterfaceContributorRoleId = '1f135831-5bbe-4924-9016-264044c00788'
var windows365NetworkUserRoleId = '7eabc9a4-85f7-4f71-b8ab-75daaccc1033'

// Reference to the existing virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' existing = {
  name: vnetName
}

// Role assignment: Windows 365 Network Interface Contributor on Resource Group
resource rgRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroupName, windows365ServicePrincipalId, windows365NetworkInterfaceContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', windows365NetworkInterfaceContributorRoleId)
    principalId: windows365ServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Windows 365 Network User on VNet
resource vnetRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, windows365ServicePrincipalId, windows365NetworkUserRoleId)
  scope: vnet
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', windows365NetworkUserRoleId)
    principalId: windows365ServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('Resource Group role assignment ID')
output rgRoleAssignmentId string = rgRoleAssignment.id

@description('VNet role assignment ID')
output vnetRoleAssignmentId string = vnetRoleAssignment.id

@description('Status message')
output status string = 'Windows 365 permissions configured successfully'
