@description('Array of private DNS zone names to create')
param zones array = [
  'privatelink.azurewebsites.net'
  'privatelink.blob.${environment().suffixes.storage}'
]

@description('Resource ID of the virtual network to link to the DNS zones')
param vnetId string

@description('Resource tags to apply to the DNS zones')
param tags object = {}

resource pdz 'Microsoft.Network/privateDnsZones@2024-06-01' = [for zoneName in zones: {
  name: zoneName
  location: 'global'
  tags: tags
}]

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zoneName, i) in zones: {
  parent: pdz[i]
  name: 'hub-vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}]
