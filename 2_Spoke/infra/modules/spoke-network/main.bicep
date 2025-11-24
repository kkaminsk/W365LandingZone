@description('Azure region for all resources')
param location string

@description('Name of the spoke virtual network')
param vnetName string = 'vnet-w365-spoke'

@description('Address space for the virtual network in CIDR notation (Class C: 192.168.x.0/24)')
param vnetAddressSpace string = '192.168.100.0/24'

@description('Address prefix for the Windows 365 Cloud PC subnet')
param cloudPCSubnetPrefix string = '192.168.100.0/26'

@description('Address prefix for the management subnet')
param mgmtSubnetPrefix string = '192.168.100.64/26'

@description('Address prefix for the Azure Virtual Desktop subnet (if needed)')
param avdSubnetPrefix string = '192.168.100.128/26'

@description('Enable Azure Virtual Desktop subnet')
param enableAvdSubnet bool = false

@description('Hub VNet ID for peering (optional - leave empty to skip peering)')
param hubVnetId string = ''

@description('Allow forwarded traffic from hub')
param allowForwardedTraffic bool = true

@description('Use remote gateways in hub')
param useRemoteGateways bool = false

@description('Resource tags to apply to all resources')
param tags object = {}

// NSG for Cloud PC subnet - Windows 365 specific rules
resource nsgCloudPC 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: '${vnetName}-cloudpc-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-Inbound'
        properties: {
          description: 'Allow RDP from authorized networks'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTPS-Outbound'
        properties: {
          description: 'Allow HTTPS outbound for Windows 365 service'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-DNS-Outbound'
        properties: {
          description: 'Allow DNS outbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

// NSG for Management subnet
resource nsgMgmt 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: '${vnetName}-mgmt-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          description: 'Allow HTTPS for management'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// NSG for AVD subnet (if enabled)
resource nsgAvd 'Microsoft.Network/networkSecurityGroups@2024-03-01' = if (enableAvdSubnet) {
  name: '${vnetName}-avd-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-Inbound'
        properties: {
          description: 'Allow RDP from authorized networks'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Spoke Virtual Network
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
    subnets: [
      {
        name: 'snet-cloudpc'
        properties: {
          addressPrefix: cloudPCSubnetPrefix
          networkSecurityGroup: {
            id: nsgCloudPC.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
      {
        name: 'snet-mgmt'
        properties: {
          addressPrefix: mgmtSubnetPrefix
          networkSecurityGroup: {
            id: nsgMgmt.id
          }
        }
      }
      {
        name: 'snet-avd'
        properties: {
          addressPrefix: avdSubnetPrefix
          networkSecurityGroup: enableAvdSubnet ? {
            id: nsgAvd.id
          } : null
        }
      }
    ]
  }
}

// VNet Peering to Hub (if hubVnetId provided)
resource peeringToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-03-01' = if (!empty(hubVnetId)) {
  parent: vnet
  name: 'peer-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false
    useRemoteGateways: useRemoteGateways
  }
}

// Outputs
@description('Virtual Network resource ID')
output vnetId string = vnet.id

@description('Virtual Network name')
output vnetName string = vnet.name

@description('Cloud PC subnet resource ID')
output cloudPCSubnetId string = vnet.properties.subnets[0].id

@description('Management subnet resource ID')
output mgmtSubnetId string = vnet.properties.subnets[1].id

@description('AVD subnet resource ID (if enabled)')
output avdSubnetId string = enableAvdSubnet ? vnet.properties.subnets[2].id : ''

@description('Cloud PC NSG resource ID')
output cloudPCNsgId string = nsgCloudPC.id

@description('Management NSG resource ID')
output mgmtNsgId string = nsgMgmt.id

@description('VNet peering status')
output peeringStatus string = !empty(hubVnetId) ? 'Configured' : 'Not Configured'
