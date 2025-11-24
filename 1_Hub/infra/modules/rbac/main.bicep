targetScope = 'resourceGroup'

@description('Optional: Group objectId to assign Owner role in this resource group')
param ownerGroupObjectId string = ''

@description('Optional: Group objectId to assign Contributor role in this resource group')
param contributorGroupObjectId string = ''

@description('Optional: Group objectId to assign Reader role in this resource group')
param readerGroupObjectId string = ''

// Owner assignment
resource raOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(ownerGroupObjectId)) {
  name: guid(resourceGroup().id, ownerGroupObjectId, 'owner')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635') // Owner
    principalId: ownerGroupObjectId
    principalType: 'Group'
  }
}

// Contributor assignment
resource raContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(contributorGroupObjectId)) {
  name: guid(resourceGroup().id, contributorGroupObjectId, 'contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: contributorGroupObjectId
    principalType: 'Group'
  }
}

// Reader assignment
resource raReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(readerGroupObjectId)) {
  name: guid(resourceGroup().id, readerGroupObjectId, 'reader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
    principalId: readerGroupObjectId
    principalType: 'Group'
  }
}
