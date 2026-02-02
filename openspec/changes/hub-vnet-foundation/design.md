## Context

The existing `1_Hub/infra/modules/hub-network/main.bicep` deploys a hub network at `10.10.0.0/20` with management, private endpoints, optional firewall, and optional gateway subnets. However, this module:
- Lacks `AzureBastionSubnet` (required for Azure Bastion)
- Lacks `snet-dns` subnet for Private DNS Resolver
- Lacks `snet-shared-services` subnet for domain controllers and management tools
- Uses a smaller address space than recommended for enterprise hub-spoke topologies

The recommendations document specifies a new hub network `hub-connectivity-prod` at `10.0.0.0/16` to align with Azure CAF patterns and accommodate all required Azure services.

**Decision Point**: Extend the existing module vs. create a parallel module for the new connectivity hub.

## Goals / Non-Goals

**Goals:**
- Create hub VNet with address space `10.0.0.0/16` in South Central US
- Include all required subnets with proper naming and sizing:
  - `AzureFirewallSubnet` (10.0.1.0/26) - Azure requirement
  - `AzureBastionSubnet` (10.0.2.0/26) - Azure requirement
  - `GatewaySubnet` (10.0.3.0/27) - Azure requirement
  - `snet-dns` (10.0.4.0/28) - Private DNS Resolver
  - `snet-shared-services` (10.0.5.0/24) - Shared services
- Create dedicated resource group `rg-hub-connectivity`
- Configure VNet diagnostic settings to Log Analytics
- Follow existing Bicep patterns and naming conventions

**Non-Goals:**
- Deploying Azure Firewall (separate change: `azure-firewall-deployment`)
- Deploying Azure Bastion (separate change: `azure-bastion-deployment`)
- VNet peering configuration (separate change: `vnet-peering-setup`)
- Route table configuration (separate change: `route-table-configuration`)
- Modifying existing `vnet-hub` at `10.10.0.0/20`

## Decisions

### 1. Extend existing hub-network module vs. create new module

**Decision**: Extend the existing `hub-network/main.bicep` module with new parameters.

**Rationale**:
- Maintains single source of truth for hub network configuration
- Avoids code duplication
- Existing deployments continue working with current defaults
- New subnets can be feature-flagged similar to existing `enableFirewall` pattern

**Alternatives Considered**:
- New module `hub-connectivity/main.bicep`: Would duplicate VNet/subnet logic; harder to maintain
- Replace existing module: Would break existing deployments

### 2. Address space selection

**Decision**: Use `10.0.0.0/16` as the new default, keeping `10.10.0.0/20` as backward-compatible option.

**Rationale**:
- `10.0.0.0/16` provides 65,534 IPs - room for growth
- Aligns with recommendations document
- Does not overlap with spoke ranges (`192.168.x.0/24`)
- Parameterized to allow customization

### 3. Subnet deployment strategy

**Decision**: Use conditional deployment with feature flags for optional subnets.

**Implementation**:
```bicep
@description('Enable Azure Bastion subnet')
param enableBastionSubnet bool = false

@description('Enable DNS resolver subnet')
param enableDnsSubnet bool = false

@description('Enable shared services subnet')
param enableSharedServicesSubnet bool = false
```

**Rationale**:
- Consistent with existing `enableFirewall` and `enableGatewaySubnet` patterns
- Allows incremental adoption
- Minimizes deployment scope for environments not needing all subnets

### 4. Resource group naming

**Decision**: Create new resource group `rg-hub-connectivity` separate from existing `rg-hub-net`.

**Rationale**:
- Isolates connectivity infrastructure from existing hub resources
- Clear separation of concerns for RBAC
- Allows independent lifecycle management

**Alternative**: Use existing `rg-hub-net` - rejected because it would commingle resources with different purposes.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Address space conflicts if existing `10.10.0.0/20` hub is still in use | Document that new hub uses different range; peering between hubs is possible if needed |
| Breaking changes to existing hub-network module | All new parameters have defaults that preserve existing behavior |
| Subnet dependencies causing deployment ordering issues | Use explicit `dependsOn` to sequence subnet creation |
| Bastion/Firewall subnets created but services not deployed | Document that subnets are prerequisites; services deployed by subsequent changes |
