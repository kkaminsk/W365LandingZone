## ADDED Requirements

### Requirement: Hub-to-spoke peering creation
The system SHALL create VNet peering resources from the hub VNet to each configured spoke VNet, completing bidirectional peering.

#### Scenario: Hub-to-spoke peering created for single spoke
- **WHEN** the hub peering module is deployed with one spoke VNet ID
- **THEN** a peering resource named `peer-hub-to-{spoke-name}` SHALL exist on the hub VNet
- **AND** the peering SHALL reference the correct spoke VNet ID

#### Scenario: Hub-to-spoke peering created for multiple spokes
- **WHEN** the hub peering module is deployed with multiple spoke VNet IDs
- **THEN** a peering resource SHALL exist for each spoke
- **AND** each peering SHALL have a unique name based on the spoke identifier

### Requirement: Peering allows virtual network access
The system SHALL configure all hub-to-spoke peerings with `allowVirtualNetworkAccess: true` to enable IP connectivity between peered networks.

#### Scenario: Virtual network access enabled
- **WHEN** a hub-to-spoke peering is created
- **THEN** the `allowVirtualNetworkAccess` property SHALL be `true`

### Requirement: Peering allows forwarded traffic
The system SHALL configure hub-to-spoke peerings with `allowForwardedTraffic: true` to enable traffic forwarding through the hub.

#### Scenario: Forwarded traffic enabled
- **WHEN** a hub-to-spoke peering is created
- **THEN** the `allowForwardedTraffic` property SHALL be `true`

### Requirement: Gateway transit support on hub side
The system SHALL configure hub-to-spoke peerings with `allowGatewayTransit: true` by default to allow spokes to use hub gateways.

#### Scenario: Gateway transit enabled by default
- **WHEN** a hub-to-spoke peering is created without explicit gateway transit setting
- **THEN** the `allowGatewayTransit` property SHALL be `true`

#### Scenario: Gateway transit can be disabled
- **WHEN** a hub-to-spoke peering is created with `allowGatewayTransit: false` specified
- **THEN** the `allowGatewayTransit` property SHALL be `false`

### Requirement: Peering naming convention
The system SHALL name hub-to-spoke peering resources using the pattern `peer-hub-to-{spoke-identifier}` where spoke-identifier is derived from the spoke configuration.

#### Scenario: Peering named correctly for student spoke
- **WHEN** a peering is created to spoke with name `spoke-student1`
- **THEN** the peering resource SHALL be named `peer-hub-to-spoke-student1`

#### Scenario: Peering named correctly for image builder spoke
- **WHEN** a peering is created to spoke with name `image-builder`
- **THEN** the peering resource SHALL be named `peer-hub-to-image-builder`

### Requirement: Cross-region peering support
The system SHALL support peering to spoke VNets in different Azure regions (global peering) using the same configuration pattern.

#### Scenario: Global peering to cross-region spoke
- **WHEN** the hub is in South Central US and spoke is in Canada Central
- **THEN** the peering SHALL be created successfully as global VNet peering
- **AND** the peering properties SHALL be identical to same-region peering

### Requirement: Spoke VNet array input
The system SHALL accept an array of spoke VNet configurations to peer with, allowing multiple spokes to be configured in a single deployment.

#### Scenario: Empty spoke array results in no peerings
- **WHEN** the peering module is deployed with an empty spoke array
- **THEN** no peering resources SHALL be created

#### Scenario: Spoke array with multiple entries creates multiple peerings
- **WHEN** the peering module is deployed with 3 spoke VNet configurations
- **THEN** exactly 3 peering resources SHALL be created

### Requirement: Hub peering module outputs
The system SHALL output peering status information for verification and downstream dependencies.

#### Scenario: Output includes peering count
- **WHEN** hub peering module completes deployment
- **THEN** an output SHALL indicate the number of peerings created

#### Scenario: Output includes peering resource IDs
- **WHEN** hub peering module completes deployment
- **THEN** an output array SHALL contain the resource IDs of all created peerings
