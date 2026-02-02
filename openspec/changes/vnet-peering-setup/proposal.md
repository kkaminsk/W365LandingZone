## Why

The existing spoke networks are completely isolated with no VNet peering to shared services. This means spokes cannot access centralized security controls (Firewall, Bastion), shared DNS, or communicate with each other through the hub. Implementing hub-spoke peering enables the CAF-recommended topology for enterprise Azure deployments.

## What Changes

- Create bidirectional VNet peering between hub and `vnet-w365-spokes-prod` (same region):
  - Hub-to-Spoke: `hub-to-spoke1-peering` with gateway transit enabled
  - Spoke-to-Hub: `spoke1-to-hub-peering` with use remote gateways
- Create bidirectional global VNet peering between hub and `w365-image-vnet-student1` (cross-region):
  - Hub-to-Spoke: `hub-to-spoke2-global-peering` for Canada Central image builder VNet
  - Spoke-to-Hub: `spoke2-to-hub-global-peering`
- Configure peering properties:
  - Allow virtual network access: true
  - Allow forwarded traffic: true
  - Allow gateway transit on hub side
- Update spoke deployment to optionally establish peering during deployment

## Capabilities

### New Capabilities
- `vnet-peering`: Hub-spoke network connectivity enabling centralized services access, cross-spoke communication via hub, and gateway transit for hybrid connectivity

### Modified Capabilities
<!-- None - peering is additive network configuration -->

## Impact

- **Connectivity**: Spokes gain access to hub services (Bastion, Firewall, DNS, shared services)
- **Cost**: ~$10/TB for same-region peering, ~$35/TB for global peering (cross-region)
- **Dependencies**: Requires `hub-vnet-foundation` change; hub must exist before peering can be established
- **New Code**:
  - Bicep module at `1_Hub/infra/modules/vnet-peering/`
  - Updates to `2_Spoke/infra/envs/prod/main.bicep` for spoke-side peering
- **Breaking**: Spoke routing will change once peering + route tables are active
