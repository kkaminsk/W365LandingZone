@description('Azure region for the Log Analytics workspace')
param location string

@description('Name of the Log Analytics workspace')
param name string = 'log-ops-hub'

@description('Number of days to retain logs (30-730)')
param retentionDays int = 30

@description('Resource tags to apply to the workspace')
param tags object = {}

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

output lawId string = law.id
output lawName string = law.name
