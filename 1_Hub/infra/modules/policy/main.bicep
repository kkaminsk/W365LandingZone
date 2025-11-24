targetScope = 'subscription'

@description('List of allowed Azure regions for resource deployment')
param allowedLocations array = [
  'southcentralus'
  'canadaeast'
]

@description('Enable allowed locations policy')
param enableLocationPolicy bool = false

// Built-in Azure Policy for allowed locations
// Note: This uses the built-in policy which may not exist in all subscriptions
// Set enableLocationPolicy=true to enable this policy assignment
resource allowedLocationsAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = if (enableLocationPolicy) {
  name: 'allowed-locations'
  properties: {
    displayName: 'Allowed locations'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}
