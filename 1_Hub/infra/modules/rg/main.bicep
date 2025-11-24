targetScope = 'subscription'

@description('Azure region for the resource groups')
param location string

@description('Name of the network resource group')
param rgNetName string = 'rg-hub-net'

@description('Name of the operations resource group')
param rgOpsName string = 'rg-hub-ops'

@description('Resource tags to apply to all resource groups')
param tags object = {}

resource rgNet 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgNetName
  location: location
  tags: tags
}

resource rgOps 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgOpsName
  location: location
  tags: tags
}

output rgNetId string = rgNet.id
output rgOpsId string = rgOps.id
output rgNetName string = rgNet.name
output rgOpsName string = rgOps.name
