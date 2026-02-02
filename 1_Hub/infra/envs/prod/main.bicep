targetScope = 'subscription'

@description('Primary Azure region for deployment')
param location string = 'southcentralus'

@description('Environment name (prod, dev, test)')
param env string = 'prod'

@description('Common tags applied to all resources')
param tags object = {
  env: env
  owner: 'platform-team'
  costCenter: '1000'
  dataSensitivity: 'internal'
}

@description('List of allowed Azure regions for policy enforcement')
param allowedLocations array = [
  'southcentralus'
  'canadaeast'
]

@description('Object ID of the network administrators AAD group')
@secure()
param networkAdminsGroupObjectId string = ''

@description('Object ID of the operations team AAD group')
@secure()
param opsGroupObjectId string = ''

@description('Enable Azure Firewall deployment (requires Network Contributor permissions)')
param enableFirewall bool = false

@description('Enable connectivity hub with expanded subnets')
param enableConnectivityHub bool = false

@description('Enable Azure Bastion subnet in connectivity hub')
param enableBastionSubnet bool = false

@description('Enable DNS resolver subnet in connectivity hub')
param enableDnsSubnet bool = false

@description('Enable shared services subnet in connectivity hub')
param enableSharedServicesSubnet bool = false

var rgNetName = 'rg-hub-net'
var rgOpsName = 'rg-hub-ops'
var rgConnectivityName = 'rg-hub-connectivity'

module rg '../../modules/rg/main.bicep' = {
  name: 'rg'
  scope: subscription()
  params: {
    location: location
    rgNetName: rgNetName
    rgOpsName: rgOpsName
    rgConnectivityName: rgConnectivityName
    enableConnectivityRg: enableConnectivityHub
    tags: tags
  }
}

module law '../../modules/log-analytics/main.bicep' = {
  name: 'logAnalytics'
  scope: resourceGroup(rgOpsName)
  dependsOn: [ rg ]
  params: {
    location: location
    name: 'log-ops-hub'
    retentionDays: 30
    tags: tags
  }
}

module net '../../modules/hub-network/main.bicep' = {
  name: 'hubNetwork'
  scope: resourceGroup(rgNetName)
  dependsOn: [ rg, law ]
  params: {
    location: location
    vnetName: 'vnet-hub'
    vnetAddressSpace: '10.10.0.0/20'
    mgmtSubnetPrefix: '10.10.0.0/24'
    privEndpointsSubnetPrefix: '10.10.1.0/24'
    enableGatewaySubnet: false
    enableFirewall: enableFirewall
    firewallSubnetPrefix: '10.10.2.0/26'
    lawId: law.outputs.lawId
    tags: tags
  }
}

// Connectivity hub network (larger address space with Bastion, DNS, shared services subnets)
module connectivityNet '../../modules/hub-network/main.bicep' = if (enableConnectivityHub) {
  name: 'connectivityNetwork'
  scope: resourceGroup(rgConnectivityName)
  dependsOn: [ rg, law ]
  params: {
    location: location
    vnetName: 'hub-connectivity-prod'
    vnetAddressSpace: '10.0.0.0/16'
    mgmtSubnetPrefix: '10.0.0.0/24'
    privEndpointsSubnetPrefix: '10.0.6.0/24'
    enableGatewaySubnet: true
    gatewaySubnetPrefix: '10.0.3.0/27'
    enableFirewall: enableFirewall
    firewallSubnetPrefix: '10.0.1.0/26'
    enableBastionSubnet: enableBastionSubnet
    bastionSubnetPrefix: '10.0.2.0/26'
    enableDnsSubnet: enableDnsSubnet
    dnsSubnetPrefix: '10.0.4.0/28'
    enableSharedServicesSubnet: enableSharedServicesSubnet
    sharedServicesSubnetPrefix: '10.0.5.0/24'
    lawId: law.outputs.lawId
    tags: tags
  }
}

module pdns '../../modules/private-dns/main.bicep' = {
  name: 'privateDns'
  scope: resourceGroup(rgNetName)
  dependsOn: [ net ]
  params: {
    vnetId: net.outputs.vnetId
    zones: [
      'privatelink.azurewebsites.net'
      'privatelink.blob.${environment().suffixes.storage}'
    ]
    tags: tags
  }
}

module subDiag '../../modules/diagnostics/subscription.bicep' = {
  name: 'subscriptionDiagnostics'
  scope: subscription()
  params: {
    lawId: law.outputs.lawId
  }
}

module policy '../../modules/policy/main.bicep' = {
  name: 'policy'
  scope: subscription()
  params: {
    allowedLocations: allowedLocations
  }
}

// RBAC assignments per RG (module is RG-scoped)
module rbacNet '../../modules/rbac/main.bicep' = {
  name: 'rbacNet'
  scope: resourceGroup(rgNetName)
  dependsOn: [ rg ]
  params: {
    ownerGroupObjectId: networkAdminsGroupObjectId
  }
}

module rbacOps '../../modules/rbac/main.bicep' = {
  name: 'rbacOps'
  scope: resourceGroup(rgOpsName)
  dependsOn: [ rg ]
  params: {
    contributorGroupObjectId: opsGroupObjectId
  }
}

module budget '../../modules/budget/main.bicep' = {
  name: 'budget'
  scope: subscription()
  params: {
    subscriptionBudgetAmount: 200
  }
}

output vnetId string = net.outputs.vnetId
output lawId string = law.outputs.lawId
