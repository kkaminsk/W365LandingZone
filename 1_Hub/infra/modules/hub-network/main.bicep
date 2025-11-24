@description('Azure region for all resources')
param location string

@description('Name of the hub virtual network')
param vnetName string = 'vnet-hub'

@description('Address space for the virtual network in CIDR notation')
param vnetAddressSpace string = '10.10.0.0/20'

@description('Address prefix for the management subnet')
param mgmtSubnetPrefix string = '10.10.0.0/24'

@description('Address prefix for the private endpoints subnet')
param privEndpointsSubnetPrefix string = '10.10.1.0/24'

@description('Enable Gateway subnet for VPN/ExpressRoute')
param enableGatewaySubnet bool = false

@description('Address prefix for the Gateway subnet')
param gatewaySubnetPrefix string = '10.10.3.0/27'

@description('Enable Azure Firewall deployment')
param enableFirewall bool = false

@description('Address prefix for the Azure Firewall subnet')
param firewallSubnetPrefix string = '10.10.2.0/26'

@description('Resource tags to apply to all resources')
param tags object = {}

resource nsgMgmt 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: '${vnetName}-mgmt-nsg'
  location: location
  tags: tags
}

resource nsgPriv 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: '${vnetName}-priv-nsg'
  location: location
  tags: tags
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
  }
}

// Child subnets (separate resources for broad Bicep compatibility)
resource subnetMgmt 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  name: 'mgmt-snet'
  parent: vnet
  dependsOn: [ nsgMgmt ]
  properties: {
    addressPrefix: mgmtSubnetPrefix
    networkSecurityGroup: {
      id: nsgMgmt.id
    }
  }
}

resource subnetPriv 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  name: 'priv-endpoints-snet'
  parent: vnet
  dependsOn: [ nsgPriv, subnetMgmt ]
  properties: {
    addressPrefix: privEndpointsSubnetPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    networkSecurityGroup: {
      id: nsgPriv.id
    }
  }
}

resource subnetFirewall 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = if (enableFirewall) {
  name: 'AzureFirewallSubnet'
  parent: vnet
  dependsOn: [ subnetPriv ]
  properties: {
    addressPrefix: firewallSubnetPrefix
  }
}

resource subnetGateway 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = if (enableGatewaySubnet) {
  name: 'GatewaySubnet'
  parent: vnet
  dependsOn: [ subnetFirewall, subnetPriv ]
  properties: {
    addressPrefix: gatewaySubnetPrefix
  }
}

// Public IP for Azure Firewall (required for egress/DNAT)
resource fwPip 'Microsoft.Network/publicIPAddresses@2024-03-01' = if (enableFirewall) {
  name: '${vnetName}-afw-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: tags
}

// Azure Firewall (Basic tier)
resource azureFirewall 'Microsoft.Network/azureFirewalls@2024-03-01' = if (enableFirewall) {
  name: '${vnetName}-afw'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: 'azureFirewallIpConfig'
        properties: {
          subnet: {
            id: subnetFirewall.id
          }
          publicIPAddress: {
            id: fwPip.id
          }
        }
      }
    ]
  }
  tags: tags
}

output vnetId string = vnet.id
output vnetNameOut string = vnet.name
output mgmtSubnetId string = subnetMgmt.id
output privEndpointsSubnetId string = subnetPriv.id
output firewallName string = enableFirewall ? azureFirewall.name : ''
output firewallPublicIpId string = enableFirewall ? fwPip.id : ''
