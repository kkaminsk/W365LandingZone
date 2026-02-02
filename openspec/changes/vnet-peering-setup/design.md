## Context

The spoke deployment (`2_Spoke/infra/modules/spoke-network/main.bicep`) already supports spoke-to-hub peering via the `hubVnetId` parameter. When provided, it creates a `peer-to-hub` peering resource on the spoke side.

However, VNet peering is bidirectional - both sides must create their peering resource. Currently:
- **Spoke side**: Implemented (conditional on `hubVnetId`)
- **Hub side**: Not implemented - hub cannot initiate peering to spokes

The hub needs a mechanism to create hub-to-spoke peering resources for each spoke that connects.

## Goals / Non-Goals

**Goals:**
- Create hub-side peering resources to complete bidirectional peering
- Support multiple spokes peering to the same hub
- Enable gateway transit from hub (for future VPN/ExpressRoute)
- Support both same-region and cross-region (global) peering
- Maintain existing spoke-side peering logic unchanged

**Non-Goals:**
- Modifying spoke-side peering implementation (already works)
- Deploying VPN/ExpressRoute gateways (just enable transit)
- Route table configuration (separate change)
- Cross-spoke traffic routing (requires route tables)

## Decisions

### 1. Hub peering module design

**Decision**: Create a new `vnet-peering` module in hub that accepts an array of spoke VNet IDs.

**Implementation**:
```bicep
@description('Array of spoke VNet configurations to peer with')
param spokeVnets array = []
// Each item: { name: string, vnetId: string, allowGatewayTransit: bool }
```

**Rationale**:
- Single module deployment creates all hub-to-spoke peerings
- Easier to manage than individual peering modules per spoke
- Array allows dynamic spoke count

**Alternatives Considered**:
- Individual module per spoke: More complex orchestration, harder to maintain
- Inline peering in hub-network module: Would complicate the network module with peering logic

### 2. Peering naming convention

**Decision**: Use pattern `peer-hub-to-{spoke-name}` for hub-side peerings.

**Examples**:
- `peer-hub-to-spoke-student1`
- `peer-hub-to-spoke-student2`
- `peer-hub-to-image-builder`

**Rationale**:
- Clear indication of direction
- Consistent with spoke-side `peer-to-hub` naming
- Includes spoke identifier for easy identification

### 3. Gateway transit configuration

**Decision**: Enable `allowGatewayTransit: true` on hub-side peerings by default.

**Rationale**:
- Prepares hub for future VPN/ExpressRoute gateway
- No cost when gateway not deployed
- Spokes can opt-in with `useRemoteGateways: true`

### 4. Cross-region peering handling

**Decision**: Same module handles both regional and global peering - Azure automatically determines based on VNet locations.

**Rationale**:
- No code differentiation needed
- Azure API handles global peering transparently
- Cost difference is billing-only, not configuration

### 5. Deployment orchestration

**Decision**: Hub-side peering deployed after spoke exists, via separate deployment or main.bicep update.

**Workflow**:
1. Spoke deployed with `hubVnetId` (creates spoke-to-hub peering)
2. Hub peering module deployed with spoke VNet ID (creates hub-to-spoke peering)
3. Bidirectional peering established

**Rationale**:
- Allows independent spoke and hub deployments
- Spoke can be deployed before hub peering is configured
- Hub admin controls which spokes can peer

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Peering created on one side but not the other | Document that both sides must be configured; peering status shows "Disconnected" until both exist |
| Spoke VNet ID changes (redeployment) | Peering must be recreated; document in runbook |
| Gateway transit enabled but no gateway | No impact - just allows future gateway use |
| Cross-region peering costs more (~$35/TB vs ~$10/TB) | Document cost difference; flag global peerings in naming |
