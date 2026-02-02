## ADDED Requirements

### Requirement: Hub VNet creation with connectivity address space
The system SHALL create a hub virtual network named `hub-connectivity-prod` with address space `10.0.0.0/16` in the configured Azure region (default: South Central US).

#### Scenario: Hub VNet deployed with correct address space
- **WHEN** the hub deployment is executed with default parameters
- **THEN** a VNet named `hub-connectivity-prod` SHALL exist with address space `10.0.0.0/16`

#### Scenario: Hub VNet deployed in custom region
- **WHEN** the hub deployment is executed with `location` parameter set to `eastus`
- **THEN** the VNet SHALL be created in the `eastus` region

### Requirement: AzureFirewallSubnet provisioning
The system SHALL create a subnet named exactly `AzureFirewallSubnet` with address prefix `10.0.1.0/26` when firewall subnet is enabled. This name is mandated by Azure for Azure Firewall deployment.

#### Scenario: Firewall subnet created when enabled
- **WHEN** the deployment is executed with `enableFirewall: true`
- **THEN** a subnet named `AzureFirewallSubnet` SHALL exist with prefix `10.0.1.0/26`
- **AND** the subnet SHALL NOT have an NSG attached (Azure requirement)

#### Scenario: Firewall subnet not created when disabled
- **WHEN** the deployment is executed with `enableFirewall: false`
- **THEN** no subnet named `AzureFirewallSubnet` SHALL exist

### Requirement: AzureBastionSubnet provisioning
The system SHALL create a subnet named exactly `AzureBastionSubnet` with address prefix `10.0.2.0/26` when Bastion subnet is enabled. This name is mandated by Azure for Azure Bastion deployment.

#### Scenario: Bastion subnet created when enabled
- **WHEN** the deployment is executed with `enableBastionSubnet: true`
- **THEN** a subnet named `AzureBastionSubnet` SHALL exist with prefix `10.0.2.0/26`
- **AND** the subnet SHALL NOT have an NSG attached (Azure Bastion manages its own NSG)

#### Scenario: Bastion subnet not created when disabled
- **WHEN** the deployment is executed with `enableBastionSubnet: false`
- **THEN** no subnet named `AzureBastionSubnet` SHALL exist

### Requirement: GatewaySubnet provisioning
The system SHALL create a subnet named exactly `GatewaySubnet` with address prefix `10.0.3.0/27` when gateway subnet is enabled. This name is mandated by Azure for VPN/ExpressRoute gateways.

#### Scenario: Gateway subnet created when enabled
- **WHEN** the deployment is executed with `enableGatewaySubnet: true`
- **THEN** a subnet named `GatewaySubnet` SHALL exist with prefix `10.0.3.0/27`
- **AND** the subnet SHALL NOT have an NSG attached (Azure requirement)

#### Scenario: Gateway subnet not created when disabled
- **WHEN** the deployment is executed with `enableGatewaySubnet: false`
- **THEN** no subnet named `GatewaySubnet` SHALL exist

### Requirement: DNS resolver subnet provisioning
The system SHALL create a subnet named `snet-dns` with address prefix `10.0.4.0/28` when DNS subnet is enabled, for Private DNS Resolver inbound/outbound endpoints.

#### Scenario: DNS subnet created when enabled
- **WHEN** the deployment is executed with `enableDnsSubnet: true`
- **THEN** a subnet named `snet-dns` SHALL exist with prefix `10.0.4.0/28`

#### Scenario: DNS subnet delegated for resolver
- **WHEN** the DNS subnet is created
- **THEN** the subnet SHALL have delegation configured for `Microsoft.Network/dnsResolvers`

### Requirement: Shared services subnet provisioning
The system SHALL create a subnet named `snet-shared-services` with address prefix `10.0.5.0/24` when shared services subnet is enabled, for domain controllers and management tools.

#### Scenario: Shared services subnet created when enabled
- **WHEN** the deployment is executed with `enableSharedServicesSubnet: true`
- **THEN** a subnet named `snet-shared-services` SHALL exist with prefix `10.0.5.0/24`

#### Scenario: Shared services subnet has NSG
- **WHEN** the shared services subnet is created
- **THEN** an NSG named `nsg-snet-shared-services` SHALL be attached to the subnet

### Requirement: Hub connectivity resource group
The system SHALL create a resource group named `rg-hub-connectivity` to contain the hub connectivity VNet and related resources.

#### Scenario: Resource group created with correct name
- **WHEN** the hub deployment is executed
- **THEN** a resource group named `rg-hub-connectivity` SHALL exist in the target subscription

#### Scenario: Resource group has required tags
- **WHEN** the hub deployment is executed with standard tags
- **THEN** the resource group SHALL have `env`, `owner`, and `costCenter` tags applied

### Requirement: VNet diagnostic settings
The system SHALL configure diagnostic settings on the hub VNet to send logs and metrics to the Log Analytics workspace.

#### Scenario: Diagnostic settings configured
- **WHEN** the hub VNet is deployed and a Log Analytics workspace ID is provided
- **THEN** diagnostic settings SHALL be configured to send `VMProtectionAlerts` logs to Log Analytics

#### Scenario: Diagnostic settings include metrics
- **WHEN** diagnostic settings are configured
- **THEN** `AllMetrics` SHALL be enabled for the VNet

### Requirement: Subnet address prefix parameterization
The system SHALL allow customization of all subnet address prefixes via parameters while providing secure defaults.

#### Scenario: Custom subnet prefixes accepted
- **WHEN** custom address prefixes are provided for any subnet
- **THEN** the subnets SHALL be created with the specified prefixes instead of defaults

#### Scenario: Default prefixes used when not specified
- **WHEN** no custom prefixes are provided
- **THEN** the system SHALL use the documented default prefixes (10.0.1.0/26, 10.0.2.0/26, etc.)
