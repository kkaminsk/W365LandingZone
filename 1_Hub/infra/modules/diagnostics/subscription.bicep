targetScope = 'subscription'

@description('Resource ID of the Log Analytics workspace')
param lawId string

@description('Name of the diagnostic setting')
param name string = 'activity-to-law'

resource actDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: name
  scope: subscription()
  properties: {
    workspaceId: lawId
    logs: [
      { category: 'Administrative', enabled: true }
      { category: 'Security', enabled: true }
      { category: 'ServiceHealth', enabled: true }
      { category: 'Alert', enabled: true }
      { category: 'Recommendation', enabled: true }
      { category: 'Policy', enabled: true }
      { category: 'Autoscale', enabled: true }
      { category: 'ResourceHealth', enabled: true }
    ]
  }
}
