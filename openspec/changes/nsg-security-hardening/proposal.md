## Why

Current NSG rules contain critical security vulnerabilities: `nsg-spoke1-cloudpc` allows RDP 3389 inbound from Any (unnecessary for Windows 365 which uses reverse connect), and `nsg-spoke1-mgmt` allows HTTPS 443 inbound from Any (exposes management plane). These rules create direct attack vectors that must be removed now that Bastion provides secure alternative access.

## What Changes

- **BREAKING** Remove insecure inbound rules from `nsg-spoke1-cloudpc`:
  - Remove: `Allow-RDP-Inbound` (RDP 3389 from Any)
  - Windows 365 uses reverse connect; inbound RDP is not required
- **BREAKING** Remove insecure inbound rules from `nsg-spoke1-mgmt`:
  - Remove: `Allow-HTTPS-Inbound` (HTTPS 443 from Any)
- Add secure management rules to `nsg-spoke1-mgmt`:
  - `Allow-Bastion-Inbound`: RDP/SSH from Bastion subnet (10.0.2.0/26) only
  - `Allow-Hub-SharedServices-Inbound`: Allow from hub shared services (10.0.5.0/24)
  - `Deny-Internet-Inbound`: Explicit deny for internet (priority 4000)
- Update `nsg-spoke1-cloudpc` with Windows 365 optimized outbound rules:
  - `Allow-W365-Service-Outbound`: HTTPS to WindowsVirtualDesktop service tag
  - `Allow-RDP-Shortpath-Outbound`: UDP 3478 for STUN/TURN
  - `Allow-DNS-Outbound`: DNS resolution
  - `Allow-AzureAD-Outbound`: Entra ID authentication
  - `Allow-Intune-Outbound`: Intune management
- Enable NSG flow logs to Log Analytics for all NSGs

## Capabilities

### New Capabilities
<!-- None - modifying existing NSG configurations -->

### Modified Capabilities
- `spoke-nsg`: Hardening NSG rules to remove internet exposure, restrict management access to Bastion only, and optimize outbound rules for Windows 365 service requirements

## Impact

- **Security**: Eliminates critical vulnerabilities (internet-exposed RDP and HTTPS)
- **Cost**: NSG flow logs add minor Log Analytics ingestion cost
- **Dependencies**: Requires `azure-bastion-deployment` to be complete before removing management access rules (otherwise admins lose access)
- **Breaking**: **BREAKING** - Direct RDP to Cloud PCs and direct HTTPS to management VMs will stop working immediately
- **Migration**:
  1. Deploy Bastion first
  2. Train admins on Bastion access
  3. Then apply NSG hardening
- **Existing Code**: Updates to `2_Spoke/infra/modules/nsg/main.bicep`
