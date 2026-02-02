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

@description('Enable Azure Bastion subnet')
param enableBastionSubnet bool = false

@description('Address prefix for the Azure Bastion subnet')
param bastionSubnetPrefix string = '10.0.2.0/26'

@description('Enable DNS resolver subnet')
param enableDnsSubnet bool = false

@description('Address prefix for the DNS resolver subnet')
param dnsSubnetPrefix string = '10.0.4.0/28'

@description('Enable shared services subnet')
param enableSharedServicesSubnet bool = false

@description('Address prefix for the shared services subnet')
param sharedServicesSubnetPrefix string = '10.0.5.0/24'

@description('Log Analytics workspace ID for diagnostic settings (optional)')
param lawId string = ''

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

// Azure Bastion subnet (no NSG allowed per Azure requirement)
resource subnetBastion 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = if (enableBastionSubnet) {
  name: 'AzureBastionSubnet'
  parent: vnet
  dependsOn: [ subnetGateway, subnetFirewall, subnetPriv ]
  properties: {
    addressPrefix: bastionSubnetPrefix
  }
}

// DNS resolver subnet with delegation
resource subnetDns 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = if (enableDnsSubnet) {
  name: 'snet-dns'
  parent: vnet
  dependsOn: [ subnetBastion, subnetGateway, subnetFirewall, subnetPriv ]
  properties: {
    addressPrefix: dnsSubnetPrefix
    delegations: [
      {
        name: 'Microsoft.Network.dnsResolvers'
        properties: {
          serviceName: 'Microsoft.Network/dnsResolvers'
        }
      }
    ]
  }
}

// NSG for shared services subnet
resource nsgSharedServices 'Microsoft.Network/networkSecurityGroups@2024-03-01' = if (enableSharedServicesSubnet) {
  name: 'nsg-snet-shared-services'
  location: location
  tags: tags
}

// Shared services subnet
resource subnetSharedServices 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = if (enableSharedServicesSubnet) {
  name: 'snet-shared-services'
  parent: vnet
  dependsOn: [ nsgSharedServices, subnetDns, subnetBastion, subnetGateway, subnetFirewall, subnetPriv ]
  properties: {
    addressPrefix: sharedServicesSubnetPrefix
    networkSecurityGroup: {
      id: nsgSharedServices.id
    }
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

// VNet diagnostic settings
resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(lawId)) {
  name: '${vnetName}-diagnostics'
  scope: vnet
  properties: {
    workspaceId: lawId
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetNameOut string = vnet.name
output mgmtSubnetId string = subnetMgmt.id
output privEndpointsSubnetId string = subnetPriv.id
output firewallName string = enableFirewall ? azureFirewall.name : ''
output firewallPublicIpId string = enableFirewall ? fwPip.id : ''
output bastionSubnetId string = enableBastionSubnet ? subnetBastion.id : ''
output dnsSubnetId string = enableDnsSubnet ? subnetDns.id : ''
output sharedServicesSubnetId string = enableSharedServicesSubnet ? subnetSharedServices.id : ''
