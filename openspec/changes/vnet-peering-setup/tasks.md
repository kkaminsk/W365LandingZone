## 1. Create Hub Peering Module

- [ ] 1.1 Create directory `1_Hub/infra/modules/vnet-peering/`
- [ ] 1.2 Create `main.bicep` with `spokeVnets` array parameter accepting `{ name: string, vnetId: string }` objects
- [ ] 1.3 Add `hubVnetName` parameter to reference the hub VNet for peering parent
- [ ] 1.4 Add `allowGatewayTransit` parameter with default `true`
- [ ] 1.5 Implement peering resource loop using `for` to create `peer-hub-to-{name}` resources
- [ ] 1.6 Configure peering properties: `allowVirtualNetworkAccess: true`, `allowForwardedTraffic: true`
- [ ] 1.7 Add outputs for peering count and resource IDs array

## 2. Integrate with Hub Deployment

- [ ] 2.1 Add `spokeVnets` parameter to `1_Hub/infra/envs/prod/main.bicep`
- [ ] 2.2 Add vnet-peering module call with scope to hub network resource group
- [ ] 2.3 Add dependency on hub-network module (peering needs VNet to exist)
- [ ] 2.4 Pass hub VNet name from hub-network module output

## 3. Update Parameters File

- [ ] 3.1 Add `spokeVnets` array to `1_Hub/infra/envs/prod/parameters.prod.json`
- [ ] 3.2 Document example spoke configuration in parameters file comments
- [ ] 3.3 Add placeholder entries for known spokes (w365-spokes-prod, image-builder)

## 4. Update Spoke Deployment Documentation

- [ ] 4.1 Update `2_Spoke/README.md` with peering setup instructions
- [ ] 4.2 Document that spoke deployment outputs `vnetId` needed for hub peering
- [ ] 4.3 Add workflow: deploy spoke first, then add to hub's `spokeVnets` array

## 5. Validation

- [ ] 5.1 Run `.\deploy.ps1 -Validate` in 1_Hub to verify Bicep compilation
- [ ] 5.2 Run `.\deploy.ps1 -WhatIf` in 1_Hub to preview peering resources
- [ ] 5.3 Verify peering resources show correct spoke VNet IDs in what-if output
