## Why

With VNet peering alone, spoke traffic still flows directly to the internet. To enforce traffic inspection through Azure Firewall, User Defined Routes (UDRs) must force all internet-bound traffic (0.0.0.0/0) through the firewall's private IP. This "forced tunneling" pattern is essential for centralized security and compliance.

## What Changes

- Create route table `rt-spoke-to-firewall` with default route to Azure Firewall:
  - Route name: `route-to-firewall`
  - Address prefix: `0.0.0.0/0`
  - Next hop type: VirtualAppliance
  - Next hop IP: Azure Firewall private IP (10.0.1.4)
- Associate route table with spoke subnets:
  - `snet-spoke1-cloudpc`
  - `snet-spoke1-mgmt`
  - `snet-spoke1-avd` (if exists)
- Configure BGP route propagation settings appropriately
- Create separate route tables for cross-region spokes if needed

## Capabilities

### New Capabilities
- `route-tables`: User-defined routing forcing spoke internet egress through Azure Firewall for centralized inspection and logging

### Modified Capabilities
<!-- None - route tables are additive configuration -->

## Impact

- **Security**: All spoke internet traffic flows through Firewall for inspection and logging
- **Cost**: Route tables have no direct cost
- **Dependencies**: Requires `azure-firewall-deployment` (need Firewall private IP) and `vnet-peering-setup` (need connectivity to hub)
- **Performance**: Adds latency for internet-bound traffic (through Firewall)
- **New Code**: Bicep module at `1_Hub/infra/modules/route-table/`
- **Breaking**: **BREAKING** - Spoke internet connectivity will route through Firewall; if Firewall rules don't allow traffic, connectivity will fail
- **Rollback**: Remove route table association to restore direct internet access
