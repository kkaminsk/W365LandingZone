## Why

Without centralized traffic inspection, all spoke internet traffic flows directly to the internet without logging or filtering. This prevents enforcement of security policies, blocks visibility into malicious traffic, and doesn't meet compliance requirements for enterprise workloads. Azure Firewall provides centralized egress control with full traffic logging and Windows 365-specific application rules.

## What Changes

- Deploy Azure Firewall Premium in the hub network's `AzureFirewallSubnet`
- Create Standard SKU public IP address `pip-azfw-prod` for Firewall
- Create Firewall Policy `afwp-hub-prod` with rule collection groups:
  - Windows 365 required FQDNs (*.wvd.microsoft.com, login.microsoftonline.com, etc.)
  - Azure services (Entra ID, Intune, Azure Monitor)
  - Windows Update endpoints
  - DNS rules
- Enable threat intelligence-based filtering
- Configure diagnostic logging to Log Analytics
- Enable Firewall metrics and alerts

## Capabilities

### New Capabilities
- `azure-firewall`: Centralized egress firewall with application rules optimized for Windows 365, threat intelligence, and full traffic logging

### Modified Capabilities
<!-- None - Firewall is additive; spoke routing changes are in separate change -->

## Impact

- **Security**: All spoke egress traffic inspected and logged; threat intelligence blocks known malicious IPs
- **Cost**: ~$1,200/month for Premium SKU (consider Basic at ~$300/month for cost-sensitive environments)
- **Dependencies**: Requires `hub-vnet-foundation` change (needs AzureFirewallSubnet)
- **Performance**: Adds ~1-2ms latency for inspected traffic
- **New Code**: Bicep modules at `1_Hub/infra/modules/firewall/` and `1_Hub/infra/modules/firewall-policy/`
- **Operations**: Firewall rules must be maintained as Windows 365 requirements evolve
