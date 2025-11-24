# W365 Spoke Network Architecture Diagram

> **Note**: This diagram shows **Student 1** as an example. Each student (1-40) receives a unique `/24` network:
> - Student 1: `192.168.1.0/24`
> - Student 5: `192.168.5.0/24`
> - Student N: `192.168.{N}.0/24`

## 📐 Network Topology (Example: Student 1)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Azure Subscription                             │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-w365-spoke-student1-prod                 │   │
│  │                                                              │   │
│  │  ┌────────────────────────────────────────────────────┐      │   │
│  │  │  VNet: vnet-w365-spoke-student1-prod               │      │   │
│  │  │  Address Space: 192.168.1.0/24                     │      │   │
│  │  │                                                    │      │   │
│  │  │  ┌──────────────────────────────────────────┐      │      │   │
│  │  │  │  Subnet: snet-cloudpc                    │      │      │   │
│  │  │  │  Range: 192.168.1.0/26 (62 IPs)          │      │      │   │
│  │  │  │  NSG: vnet-w365-spoke-student1-...-nsg   │      │      │   │
│  │  │  │                                          │      │      │   │
│  │  │  │  [Windows 365 Cloud PCs]                 │      │      │   │
│  │  │  │  - RDP allowed from VNet                 │      │      │   │
│  │  │  │  - HTTPS outbound for W365 service       │      │      │   │
│  │  │  │  - Service Endpoints: Storage, KeyVault  │      │      │   │
│  │  │  └──────────────────────────────────────────┘      │      │   │
│  │  │                                                    │      │   │
│  │  │  ┌──────────────────────────────────────────┐      │      │   │
│  │  │  │  Subnet: snet-mgmt                       │      │      │   │
│  │  │  │  Range: 192.168.1.64/26 (62 IPs)         │      │      │   │
│  │  │  │  NSG: vnet-w365-spoke-student1-...-nsg   │      │      │   │
│  │  │  │                                          │      │      │   │
│  │  │  │  [Management Resources]                  │      │      │   │
│  │  │  │  - HTTPS allowed for management          │      │      │   │
│  │  │  └──────────────────────────────────────────┘      │      │   │
│  │  │                                                    │      │   │
│  │  │  ┌──────────────────────────────────────────┐      │      │   │
│  │  │  │  Subnet: snet-avd (Optional)             │      │      │   │
│  │  │  │  Range: 192.168.1.128/26 (62 IPs)        │      │      │   │
│  │  │  │  NSG: vnet-w365-spoke-student1-...-nsg   │      │      │   │
│  │  │  │                                          │      │      │   │
│  │  │  │  [Azure Virtual Desktop Hosts]           │      │      │   │
│  │  │  │  - Disabled by default                   │      │      │   │
│  │  │  └──────────────────────────────────────────┘      │      │   │
│  │  │                                                    │      │   │
│  │  │  Reserved: 192.168.1.192/26 (64 IPs)               │      │   │
│  │  │            for future expansion                    │      │   │
│  │  └────────────────────────────────────────────────────┘      │   │
│  │                                                              │   │
│  │  [Optional VNet Peering]                                     │   │
│  │       ↕                                                      │   │
│  │  Hub VNet (10.10.0.0/20)                                     │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔢 IP Address Allocation (Example: Student 1)

> **Note**: Replace `.1.` with `.{N}.` for other students (e.g., Student 5 uses `192.168.5.x`)

```
192.168.1.0/24 (256 Total IPs for Student 1)
│
├── 192.168.1.0 - 192.168.1.63      [snet-cloudpc]    62 usable
│   └── 192.168.1.0                    Network Address
│   └── 192.168.1.1 - .62              Usable for Cloud PCs
│   └── 192.168.1.63                   Broadcast Address
│
├── 192.168.1.64 - 192.168.1.127    [snet-mgmt]       62 usable
│   └── 192.168.1.64                   Network Address
│   └── 192.168.1.65 - .126            Usable for Management
│   └── 192.168.1.127                  Broadcast Address
│
├── 192.168.1.128 - 192.168.1.191   [snet-avd]        62 usable
│   └── 192.168.1.128                  Network Address
│   └── 192.168.1.129 - .190           Usable for AVD Hosts
│   └── 192.168.1.191                  Broadcast Address
│
└── 192.168.1.192 - 192.168.1.255   [Reserved]        64 IPs
    └── Available for future subnets
```

## 🔒 Network Security Group Rules

### Cloud PC NSG (Example: vnet-w365-spoke-student1-prod-cloudpc-nsg)

**Inbound Rules**:
```
Priority 100: Allow-RDP-Inbound
    Protocol: TCP
    Port: 3389
    Source: VirtualNetwork
    Destination: *
    Action: Allow
```

**Outbound Rules**:
```
Priority 100: Allow-HTTPS-Outbound
    Protocol: TCP
    Port: 443
    Source: *
    Destination: Internet
    Action: Allow

Priority 110: Allow-DNS-Outbound
    Protocol: *
    Port: 53
    Source: *
    Destination: *
    Action: Allow
```

### Management NSG (vnet-w365-spoke-prod-mgmt-nsg)

**Inbound Rules**:
```
Priority 100: Allow-HTTPS-Inbound
    Protocol: TCP
    Port: 443
    Source: VirtualNetwork
    Destination: *
    Action: Allow
```

### AVD NSG (vnet-w365-spoke-prod-avd-nsg) [If Enabled]

**Inbound Rules**:
```
Priority 100: Allow-RDP-Inbound
    Protocol: TCP
    Port: 3389
    Source: VirtualNetwork
    Destination: *
    Action: Allow
```

## 🔗 Hub-Spoke Peering (Optional)

```
┌──────────────────────────────────────────────────────────────┐
│                    Hub VNet                                  │
│                  10.10.0.0/20                                │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐          │
│  │ Management  │  │   Private   │  │   Firewall   │          │
│  │   Subnet    │  │  Endpoints  │  │    Subnet    │          │
│  │ 10.10.0/24  │  │ 10.10.1/24  │  │  10.10.2/26  │          │
│  └─────────────┘  └─────────────┘  └──────────────┘          │
│                                                              │
│  [Azure Firewall, Private DNS, Log Analytics]                │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        │ VNet Peering
                        │ (Bidirectional)
                        │
┌───────────────────────┴──────────────────────────────────────┐
│                 W365 Spoke VNet (Student 1)                  │
│               192.168.1.0/24                                 │
│                                                              │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐         │
│  │   Cloud PC   │  │ Management  │  │     AVD      │         │
│  │    Subnet    │  │   Subnet    │  │   Subnet     │         │
│  │  .1.0/26     │  │  .1.64/26   │  │  .1.128/26   │         │
│  └──────────────┘  └─────────────┘  └──────────────┘         │
│                                                              │
│  [Windows 365 Cloud PCs]                                     │
└──────────────────────────────────────────────────────────────┘
```

**Peering Configuration**:
- ✅ Allow Virtual Network Access: Enabled
- ✅ Allow Forwarded Traffic: Enabled
- ⚙️ Allow Gateway Transit: Disabled (spoke)
- ⚙️ Use Remote Gateways: Optional (spoke)

## 🌐 Traffic Flow

### Windows 365 Cloud PC to Internet (Example: Student 1)
```
Cloud PC (192.168.1.5)
    ↓
snet-cloudpc (NSG: Allow HTTPS)
    ↓
VNet Gateway (if peering enabled)
    ↓
Hub VNet (if peered)
    ↓
Azure Firewall (if hub has firewall)
    ↓
Internet
```

### Windows 365 Cloud PC to Azure Services (Example: Student 1)
```
Cloud PC (192.168.1.10)
    ↓
snet-cloudpc (Service Endpoints)
    ↓
Microsoft.Storage (Private)
Microsoft.KeyVault (Private)
    ↓
Azure Backbone Network
```

### Management to Cloud PC (RDP) (Example: Student 1)
```
Management VM (192.168.1.70)
    ↓
snet-mgmt
    ↓
VNet Internal Routing
    ↓
snet-cloudpc (NSG: Allow RDP from VNet)
    ↓
Cloud PC (192.168.1.5:3389)
```

## 📦 Resource Hierarchy (Example: Student 1)

```
Azure Subscription
└── Resource Group: rg-w365-spoke-student1-prod
    ├── Virtual Network: vnet-w365-spoke-student1-prod
    │   ├── Subnet: snet-cloudpc (192.168.1.0/26)
    │   ├── Subnet: snet-mgmt (192.168.1.64/26)
    │   └── Subnet: snet-avd (192.168.1.128/26) [optional]
    ├── NSG: vnet-w365-spoke-student1-prod-cloudpc-nsg
    │   └── Attached to: snet-cloudpc
    ├── NSG: vnet-w365-spoke-student1-prod-mgmt-nsg
    │   └── Attached to: snet-mgmt
    ├── NSG: vnet-w365-spoke-student1-prod-avd-nsg [optional]
    │   └── Attached to: snet-avd
    └── VNet Peering: peer-to-hub [optional]
        └── Remote VNet: Hub VNet (10.10.0.0/20)
```

## 🎯 Deployment Scope

```
Bicep Template Scope: subscription

Module Hierarchy:
    main.bicep (subscription scope)
    ├── rg module (subscription scope)
    │   └── Creates: Resource Group
    └── spoke-network module (resource group scope)
        ├── Creates: NSG (cloudpc)
        ├── Creates: NSG (mgmt)
        ├── Creates: NSG (avd) [if enabled]
        ├── Creates: Virtual Network
        └── Creates: VNet Peering [if hubVnetId provided]
```

## 🚀 Deployment Flow

```
1. Prerequisites Check
   ├── Azure PowerShell Module
   ├── Bicep CLI
   └── Azure Login

2. File Validation
   ├── main.bicep exists
   └── parameters.prod.json exists

3. Bicep Build
   └── main.bicep → main.json (ARM template)

4. Template Validation
   └── Test-AzSubscriptionDeployment

5. Deployment
   ├── Create Resource Group
   ├── Create NSGs (x3)
   ├── Create Virtual Network
   ├── Create Subnets (x3)
   └── Create VNet Peering (optional)

6. Success!
   └── Outputs: VNet ID, Subnet IDs, NSG IDs
```

---

**Visual Reference**: Use this diagram to understand the W365 spoke network architecture! 🎨
