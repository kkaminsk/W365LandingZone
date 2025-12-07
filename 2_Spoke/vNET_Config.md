# Spoke Virtual Network Configuration

## Overview

The Spoke virtual network is designed to host Windows 365 Cloud PCs and related management resources. It uses a hub-and-spoke topology with optional peering to a central hub VNet for shared services.

## Virtual Network Architecture

### VNet Specifications

| Property | Value | Description |
|----------|-------|-------------|
| **Name** | `vnet-w365-spoke-student{N}-{env}` | Student number (1-40) provides unique addressing |
| **Address Space** | `192.168.{N}.0/24` | Class C network, where N = student number |
| **Location** | `southcentralus` (default) | Azure region for deployment |
| **Peering** | Optional to Hub VNet | Enables connectivity to shared services |

### IP Address Allocation

The spoke VNet uses a `/24` address space (256 addresses) divided into three subnets:

```
Student 1:  192.168.1.0/24
Student 2:  192.168.2.0/24
...
Student 40: 192.168.40.0/24
```

## Subnets

### 1. Cloud PC Subnet (`snet-cloudpc`)

**Purpose**: Hosts Windows 365 Cloud PC virtual machines

| Property | Value |
|----------|-------|
| **Address Prefix** | `192.168.{N}.0/26` |
| **Available IPs** | 64 addresses (59 usable) |
| **NSG** | `{vnetName}-cloudpc-nsg` |
| **Service Endpoints** | Microsoft.Storage, Microsoft.KeyVault |

**IP Range Example (Student 1)**:
- Network: `192.168.1.0/26`
- First usable: `192.168.1.4`
- Last usable: `192.168.1.62`
- Broadcast: `192.168.1.63`

### 2. Management Subnet (`snet-mgmt`)

**Purpose**: Management and administrative resources

| Property | Value |
|----------|-------|
| **Address Prefix** | `192.168.{N}.64/26` |
| **Available IPs** | 64 addresses (59 usable) |
| **NSG** | `{vnetName}-mgmt-nsg` |
| **Service Endpoints** | None |

**IP Range Example (Student 1)**:
- Network: `192.168.1.64/26`
- First usable: `192.168.1.68`
- Last usable: `192.168.1.126`
- Broadcast: `192.168.1.127`

### 3. Azure Virtual Desktop Subnet (`snet-avd`)

**Purpose**: Optional subnet for Azure Virtual Desktop session hosts

| Property | Value |
|----------|-------|
| **Address Prefix** | `192.168.{N}.128/26` |
| **Available IPs** | 64 addresses (59 usable) |
| **NSG** | `{vnetName}-avd-nsg` (when enabled) |
| **Enabled by Default** | No (controlled by `enableAvdSubnet` parameter) |

**IP Range Example (Student 1)**:
- Network: `192.168.1.128/26`
- First usable: `192.168.1.132`
- Last usable: `192.168.1.190`
- Broadcast: `192.168.1.191`

## Network Security Groups (NSGs)

### Cloud PC NSG (`{vnetName}-cloudpc-nsg`)

Protects the Windows 365 Cloud PC subnet with specific rules for remote access and service connectivity.

#### Security Rules

| Priority | Name | Direction | Access | Protocol | Source | Source Port | Destination | Dest Port | Description |
|----------|------|-----------|--------|----------|--------|-------------|-------------|-----------|-------------|
| **100** | `Allow-RDP-Inbound` | Inbound | Allow | TCP | VirtualNetwork | * | * | 3389 | Allow RDP from authorized networks |
| **100** | `Allow-HTTPS-Outbound` | Outbound | Allow | TCP | * | * | Internet | 443 | Allow HTTPS outbound for Windows 365 service |
| **110** | `Allow-DNS-Outbound` | Outbound | Allow | * | * | * | * | 53 | Allow DNS outbound |

#### Rule Details

**Inbound Rules:**

1. **Allow-RDP-Inbound** (Priority 100)
   - **Purpose**: Enables Remote Desktop Protocol access to Cloud PCs
   - **Source**: VirtualNetwork service tag (restricts access to Azure VNet traffic only)
   - **Destination Port**: 3389 (RDP)
   - **Protocol**: TCP
   - **Security Note**: Only allows RDP from within the virtual network, blocking internet-based RDP attempts

**Outbound Rules:**

1. **Allow-HTTPS-Outbound** (Priority 100)
   - **Purpose**: Required for Windows 365 service communication
   - **Destination**: Internet (Windows 365 endpoints)
   - **Destination Port**: 443 (HTTPS)
   - **Protocol**: TCP
   - **Required For**: Cloud PC provisioning, management, and updates

2. **Allow-DNS-Outbound** (Priority 110)
   - **Purpose**: Name resolution for all services
   - **Destination**: Any (allows both Azure DNS and custom DNS)
   - **Destination Port**: 53 (DNS)
   - **Protocol**: Any (TCP and UDP)
   - **Required For**: Domain name resolution

### Management NSG (`{vnetName}-mgmt-nsg`)

Protects the management subnet with rules for administrative access.

#### Security Rules

| Priority | Name | Direction | Access | Protocol | Source | Source Port | Destination | Dest Port | Description |
|----------|------|-----------|--------|----------|--------|-------------|-------------|-----------|-------------|
| **100** | `Allow-HTTPS-Inbound` | Inbound | Allow | TCP | VirtualNetwork | * | * | 443 | Allow HTTPS for management |

#### Rule Details

**Inbound Rules:**

1. **Allow-HTTPS-Inbound** (Priority 100)
   - **Purpose**: Secure management traffic (Azure Portal, APIs, management tools)
   - **Source**: VirtualNetwork service tag
   - **Destination Port**: 443 (HTTPS)
   - **Protocol**: TCP
   - **Use Cases**: Azure management operations, monitoring, configuration

### AVD NSG (`{vnetName}-avd-nsg`)

*Only created when `enableAvdSubnet = true`*

Protects the Azure Virtual Desktop subnet with rules for session host connectivity.

#### Security Rules

| Priority | Name | Direction | Access | Protocol | Source | Source Port | Destination | Dest Port | Description |
|----------|------|-----------|--------|----------|--------|-------------|-------------|-----------|-------------|
| **100** | `Allow-RDP-Inbound` | Inbound | Allow | TCP | VirtualNetwork | * | * | 3389 | Allow RDP from authorized networks |

#### Rule Details

**Inbound Rules:**

1. **Allow-RDP-Inbound** (Priority 100)
   - **Purpose**: Enables RDP access to AVD session hosts
   - **Source**: VirtualNetwork service tag
   - **Destination Port**: 3389 (RDP)
   - **Protocol**: TCP
   - **Security Note**: Identical to Cloud PC NSG RDP rule

## VNet Peering

### Hub-to-Spoke Peering

When configured, the spoke VNet peers with a central hub VNet for shared services.

| Property | Value | Description |
|----------|-------|-------------|
| **Peering Name** | `peer-to-hub` | Name of the peering connection |
| **Hub VNet ID** | Provided via `hubVnetId` parameter | Resource ID of hub VNet |
| **Allow VNet Access** | `true` | Enables communication between VNets |
| **Allow Forwarded Traffic** | `true` (default) | Allows traffic forwarded by hub NVAs |
| **Allow Gateway Transit** | `false` | Spoke does not provide gateway |
| **Use Remote Gateways** | `false` (default) | Can be enabled to use hub's VPN/ExpressRoute gateway |

### Peering Configuration

```bicep
// Peering is conditional - only created if hubVnetId is provided
peeringToHub: {
  remoteVirtualNetwork: { id: hubVnetId }
  allowVirtualNetworkAccess: true
  allowForwardedTraffic: true
  allowGatewayTransit: false
  useRemoteGateways: false  // Set to true if hub has VPN/ExpressRoute
}
```

## Security Considerations

### Default Security Posture

1. **Inbound Traffic**: Restricted to VirtualNetwork service tag by default
2. **Outbound Traffic**: Explicitly allows HTTPS and DNS. **Note**: Other traffic (e.g., HTTP) is also **allowed** by default Azure rules (`AllowInternetOutBound`) as there is no explicit "Deny All" rule.
3. **No Public IPs**: Subnets do not have direct internet access by default
4. **Service Endpoints**: Cloud PC subnet has endpoints for Storage and KeyVault

### Additional Security Recommendations

1. **Restrict Outbound Traffic**: Add a 'Deny-All-Outbound' rule (e.g., Priority 4000) to block non-whitelisted traffic like HTTP.
2. **Enable NSG Flow Logs**: Monitor and audit network traffic
3. **Azure Firewall**: Route internet-bound traffic through hub's Azure Firewall
4. **Private Endpoints**: Use for Azure PaaS services instead of service endpoints
5. **Just-In-Time Access**: Implement JIT VM access for management resources
6. **Network Watcher**: Enable for network diagnostics and monitoring

## Service Endpoints

The Cloud PC subnet includes service endpoints for:

- **Microsoft.Storage**: Direct access to Azure Storage without internet traversal
- **Microsoft.KeyVault**: Secure access to Key Vault for secrets and certificates

## Deployment Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `location` | string | Azure region (default: southcentralus) |
| `studentNumber` | int | Student number 1-40 for unique addressing |
| `windows365ServicePrincipalId` | string | Windows 365 service principal object ID |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `env` | string | `prod` | Environment name (prod, dev, test) |
| `enableAvdSubnet` | bool | `false` | Enable Azure Virtual Desktop subnet |
| `hubVnetId` | string | `''` | Hub VNet resource ID for peering |
| `allowForwardedTraffic` | bool | `true` | Allow forwarded traffic from hub |
| `useRemoteGateways` | bool | `false` | Use hub's VPN/ExpressRoute gateway |

## Outputs

The deployment provides the following outputs:

- `vnetId`: Virtual Network resource ID
- `vnetName`: Virtual Network name
- `cloudPCSubnetId`: Cloud PC subnet resource ID
- `mgmtSubnetId`: Management subnet resource ID
- `avdSubnetId`: AVD subnet resource ID (if enabled)
- `cloudPCNsgId`: Cloud PC NSG resource ID
- `mgmtNsgId`: Management NSG resource ID
- `peeringStatus`: VNet peering status

## Network Topology Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Spoke VNet: 192.168.{N}.0/24                               │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ snet-cloudpc: 192.168.{N}.0/26                     │    │
│  │ NSG: cloudpc-nsg                                   │    │
│  │ - Windows 365 Cloud PCs                            │    │
│  │ - Service Endpoints: Storage, KeyVault             │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ snet-mgmt: 192.168.{N}.64/26                       │    │
│  │ NSG: mgmt-nsg                                      │    │
│  │ - Management resources                             │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ snet-avd: 192.168.{N}.128/26 (optional)            │    │
│  │ NSG: avd-nsg                                       │    │
│  │ - Azure Virtual Desktop session hosts              │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
└──────────────────────┬──────────────────────────────────────┘
                       │ VNet Peering (optional)
                       │ peer-to-hub
                       ↓
┌─────────────────────────────────────────────────────────────┐
│  Hub VNet                                                   │
│  - Shared services                                          │
│  - Azure Firewall                                           │
│  - VPN/ExpressRoute Gateway                                 │
└─────────────────────────────────────────────────────────────┘
```

## Related Documentation

- [Hub Configuration](../1_Hub/README.md)
- [Architecture Overview](./ARCHITECTURE-DIAGRAM.md)
- [Deployment Guide](./README.md)
