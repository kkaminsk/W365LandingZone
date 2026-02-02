## Why

The current network architecture lacks a centralized hub network. VNets named for hub-spoke topology (`vnet-w365-spokes-prod`) exist but without the actual hub, leaving no centralized security controls, shared services, or VNet peering infrastructure. This creates isolated networks that cannot share resources or implement enterprise security patterns.

## What Changes

- Create new hub virtual network `hub-connectivity-prod` with address space `10.0.0.0/16` in South Central US
- Add required Azure subnets with specific naming conventions:
  - `AzureFirewallSubnet` (10.0.1.0/26) - Required name for Azure Firewall deployment
  - `AzureBastionSubnet` (10.0.2.0/26) - Required name for Azure Bastion deployment
  - `GatewaySubnet` (10.0.3.0/27) - Required name for VPN/ExpressRoute Gateway
  - `snet-dns` (10.0.4.0/28) - Private DNS Resolver endpoints
  - `snet-shared-services` (10.0.5.0/24) - Domain controllers, management tools
- Create hub resource group `rg-hub-connectivity`
- Configure diagnostic settings for the VNet

## Capabilities

### New Capabilities
- `hub-vnet`: Core hub virtual network infrastructure with properly sized subnets for Azure Firewall, Bastion, Gateway, DNS, and shared services

### Modified Capabilities
<!-- None - this is foundational infrastructure that existing spokes will peer to later -->

## Impact

- **New Infrastructure**: Creates the foundational hub network required by Azure CAF hub-spoke topology
- **Dependencies**: Enables subsequent deployment of Azure Firewall, Azure Bastion, and VNet peering
- **Cost**: VNet has no direct cost; subnets reserved for future Firewall (~$1,200/mo) and Bastion (~$140/mo)
- **Existing Code**: New Bicep modules in `1_Hub/infra/modules/hub-vnet/`
- **Deployment**: Subscription-scoped deployment following existing patterns
