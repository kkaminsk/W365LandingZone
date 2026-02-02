## 1. Module Updates

- [ ] 1.1 Add `enableBastionSubnet` parameter to `1_Hub/infra/modules/hub-network/main.bicep` with default `false`
- [ ] 1.2 Add `bastionSubnetPrefix` parameter with default `10.0.2.0/26`
- [ ] 1.3 Add `enableDnsSubnet` parameter with default `false`
- [ ] 1.4 Add `dnsSubnetPrefix` parameter with default `10.0.4.0/28`
- [ ] 1.5 Add `enableSharedServicesSubnet` parameter with default `false`
- [ ] 1.6 Add `sharedServicesSubnetPrefix` parameter with default `10.0.5.0/24`

## 2. Subnet Resources

- [ ] 2.1 Create conditional `AzureBastionSubnet` resource (no NSG) with proper dependsOn chain
- [ ] 2.2 Create conditional `snet-dns` resource with `Microsoft.Network/dnsResolvers` delegation
- [ ] 2.3 Create NSG `nsg-snet-shared-services` for shared services subnet
- [ ] 2.4 Create conditional `snet-shared-services` resource with NSG attachment

## 3. Resource Group Updates

- [ ] 3.1 Add `rg-hub-connectivity` to `1_Hub/infra/modules/rg/main.bicep` module
- [ ] 3.2 Update `1_Hub/infra/envs/prod/main.bicep` to deploy connectivity resource group

## 4. Diagnostic Settings

- [ ] 4.1 Add VNet diagnostic settings resource to hub-network module
- [ ] 4.2 Add `lawId` parameter to hub-network module for Log Analytics workspace ID
- [ ] 4.3 Configure `VMProtectionAlerts` logs and `AllMetrics` to be sent to Log Analytics

## 5. Module Outputs

- [ ] 5.1 Add `bastionSubnetId` output (empty string if not enabled)
- [ ] 5.2 Add `dnsSubnetId` output (empty string if not enabled)
- [ ] 5.3 Add `sharedServicesSubnetId` output (empty string if not enabled)

## 6. Environment Configuration

- [ ] 6.1 Update `1_Hub/infra/envs/prod/parameters.prod.json` with new subnet flags set to `true`
- [ ] 6.2 Update main.bicep to pass new parameters to hub-network module
- [ ] 6.3 Configure VNet address space to `10.0.0.0/16` for connectivity hub

## 7. Validation

- [ ] 7.1 Run `.\deploy.ps1 -Validate` to verify Bicep compilation
- [ ] 7.2 Run `.\deploy.ps1 -WhatIf` to preview ARM changes
- [ ] 7.3 Update `verify.ps1` to check for new subnets when enabled
