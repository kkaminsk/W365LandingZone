## Why

The current architecture exposes management subnets directly to the internet via NSG rules allowing HTTPS 443 inbound from Any. This is a critical security vulnerability. Azure Bastion provides secure, auditable RDP/SSH access to VMs without exposing them to the public internet, aligning with zero-trust security principles.

## What Changes

- Deploy Azure Bastion Standard SKU in the hub network's `AzureBastionSubnet`
- Create Standard SKU public IP address `pip-bastion-prod` for Bastion
- Configure Bastion host `bastion-hub-prod` with Standard features:
  - Native client support (RDP/SSH from local clients)
  - IP-based connection
  - Shareable link
  - Kerberos authentication
- Enable diagnostic logging to Log Analytics
- Create Bastion-specific NSG for the AzureBastionSubnet

## Capabilities

### New Capabilities
- `azure-bastion`: Secure management access infrastructure providing audited RDP/SSH connectivity to spoke VMs without public internet exposure

### Modified Capabilities
<!-- None - Bastion is additive infrastructure -->

## Impact

- **Security**: Eliminates need for public RDP/SSH access to management VMs
- **Cost**: ~$140/month for Standard SKU (Basic available at ~$70/month with reduced features)
- **Dependencies**: Requires `hub-vnet-foundation` change to be deployed first (needs AzureBastionSubnet)
- **New Code**: Bicep module at `1_Hub/infra/modules/bastion/`
- **User Workflow**: Admins will access VMs via Azure Portal Bastion or native client instead of direct RDP
