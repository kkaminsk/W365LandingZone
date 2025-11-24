targetScope = 'subscription'

@description('Azure region for resource group')
param location string

@description('Name of the resource group for Windows 365 spoke network')
param rgName string = 'rg-w365-spoke'

@description('Resource tags to apply')
param tags object = {}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

@description('Resource Group ID')
output resourceGroupId string = rg.id

@description('Resource Group name')
output resourceGroupName string = rg.name
