targetScope = 'subscription'

@description('Primary Azure region for deployment')
param location string = 'southcentralus'

@description('Environment name (prod, dev, test)')
param env string = 'prod'

@description('Student number (1-40) for unique IP addressing')
@minValue(1)
@maxValue(40)
param studentNumber int = 1

@description('Common tags applied to all resources')
param tags object = {
  env: env
  workload: 'Windows365'
  owner: 'platform-team'
  costCenter: '1000'
}

// Calculate IP addresses based on student number to avoid conflicts
// Student 1 = 192.168.1.0/24, Student 2 = 192.168.2.0/24, etc.
var thirdOctet = studentNumber
var vnetAddressSpace = '192.168.${thirdOctet}.0/24'
var cloudPCSubnetPrefix = '192.168.${thirdOctet}.0/26'
var mgmtSubnetPrefix = '192.168.${thirdOctet}.64/26'
var avdSubnetPrefix = '192.168.${thirdOctet}.128/26'

@description('Enable Azure Virtual Desktop subnet')
param enableAvdSubnet bool = false

@description('Hub VNet resource ID for peering (optional)')
param hubVnetId string = ''

@description('Allow forwarded traffic from hub')
param allowForwardedTraffic bool = true

@description('Use remote gateways in hub VNet')
param useRemoteGateways bool = false

@description('Windows 365 Service Principal Object ID (required for permissions)')
param windows365ServicePrincipalId string

var rgName = 'rg-w365-spoke-student${studentNumber}-${env}'
var vnetName = 'vnet-w365-spoke-student${studentNumber}-${env}'

// Resource Group
module rg '../../modules/rg/main.bicep' = {
  name: 'rg-w365-spoke-student${studentNumber}'
  scope: subscription()
  params: {
    location: location
    rgName: rgName
    tags: tags
  }
}

// Spoke Network
module spokeNetwork '../../modules/spoke-network/main.bicep' = {
  name: 'spoke-network-w365-student${studentNumber}'
  scope: resourceGroup(rgName)
  dependsOn: [ rg ]
  params: {
    location: location
    vnetName: vnetName
    vnetAddressSpace: vnetAddressSpace
    cloudPCSubnetPrefix: cloudPCSubnetPrefix
    mgmtSubnetPrefix: mgmtSubnetPrefix
    avdSubnetPrefix: avdSubnetPrefix
    enableAvdSubnet: enableAvdSubnet
    hubVnetId: hubVnetId
    allowForwardedTraffic: allowForwardedTraffic
    useRemoteGateways: useRemoteGateways
    tags: tags
  }
}

// Windows 365 Permissions
module w365Permissions '../../modules/w365-permissions/main.bicep' = {
  name: 'w365-permissions-student${studentNumber}'
  scope: resourceGroup(rgName)
  dependsOn: [ spokeNetwork ]
  params: {
    resourceGroupName: rgName
    vnetName: vnetName
    windows365ServicePrincipalId: windows365ServicePrincipalId
  }
}

// Outputs
@description('Resource Group name')
output resourceGroupName string = rg.outputs.resourceGroupName

@description('Virtual Network ID')
output vnetId string = spokeNetwork.outputs.vnetId

@description('Virtual Network name')
output vnetName string = spokeNetwork.outputs.vnetName

@description('Cloud PC subnet ID')
output cloudPCSubnetId string = spokeNetwork.outputs.cloudPCSubnetId

@description('Management subnet ID')
output mgmtSubnetId string = spokeNetwork.outputs.mgmtSubnetId

@description('AVD subnet ID')
output avdSubnetId string = spokeNetwork.outputs.avdSubnetId

@description('Peering status to hub')
output peeringStatus string = spokeNetwork.outputs.peeringStatus

@description('Windows 365 permissions status')
output w365PermissionsStatus string = w365Permissions.outputs.status
