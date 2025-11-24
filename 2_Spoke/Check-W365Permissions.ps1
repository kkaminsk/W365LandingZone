<#
.SYNOPSIS
    Checks Windows 365 permissions on Azure resources

.DESCRIPTION
    This script verifies that the Windows 365 service principal has the required permissions
    on your Azure subscription, resource group, and virtual network.
    It supports tenant selection to ensure you're connecting to the correct tenant.

.PARAMETER TenantId
    Optional Azure AD tenant ID. If not provided, you'll be prompted to select from available tenants.

.EXAMPLE
    .\Check-W365Permissions.ps1
    Run with interactive tenant selection

.EXAMPLE
    .\Check-W365Permissions.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    Run with specific tenant ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantId
)

# Setup logging
$timestamp = Get-Date -Format "MM-dd-HH-mm"
$logPath = "$env:USERPROFILE\Documents\Check-W365Permissions-$timestamp.log"

# Function to write to both console and log file
function Write-LogOutput {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
    Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

Write-LogOutput "Starting Windows 365 Permission Check Script" "Cyan"
Write-LogOutput "Log file: $logPath" "Gray"

# Connect to your Azure Account
Write-LogOutput "`nConnecting to Azure Account..." "Cyan"
Write-LogOutput "⚠️  A browser window will open for authentication. Please complete the sign-in process." "Yellow"
Write-LogOutput "    (The browser window may open behind other windows - check your taskbar)" "Gray"

# Initial connection to enumerate tenants
Connect-AzAccount | Out-Null

# Get available tenants
Write-LogOutput "`n🔍 Retrieving available tenants..." "Cyan"
$tenants = @(Get-AzTenant)

if ($tenants.Count -eq 0) {
    Write-LogOutput "❌ No accessible tenants found." "Red"
    return
}

$selectedTenant = $null

if ($TenantId) {
    # Use specified tenant ID
    $selectedTenant = $tenants | Where-Object { $_.Id -eq $TenantId }
    if (-not $selectedTenant) {
        Write-LogOutput "❌ Specified tenant ID '$TenantId' is not accessible." "Red"
        return
    }
    Write-LogOutput "✅ Using specified tenant: $($selectedTenant.Name) ($($selectedTenant.Id))" "Green"
}
elseif ($tenants.Count -eq 1) {
    # Only one tenant available
    $selectedTenant = $tenants[0]
    Write-LogOutput "✅ Single tenant detected: $($selectedTenant.Name) ($($selectedTenant.Id))" "Green"
}
else {
    # Prompt user to select a tenant
    Write-LogOutput "`nAvailable Tenants:" "Yellow"
    for ($i = 0; $i -lt $tenants.Count; $i++) {
        $tenant = $tenants[$i]
        Write-LogOutput "  [$($i + 1)] $($tenant.Name) ($($tenant.Id))"
    }
    
    do {
        $tenantChoice = Read-Host "`nEnter the number of the tenant you want to use (1-$($tenants.Count))"
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): User selected tenant option: $tenantChoice"
        $tenantIndex = [int]$tenantChoice - 1
    } while ($tenantIndex -lt 0 -or $tenantIndex -ge $tenants.Count)
    
    $selectedTenant = $tenants[$tenantIndex]
    Write-LogOutput "✅ Selected tenant: $($selectedTenant.Name) ($($selectedTenant.Id))" "Green"
}

# Connect to the selected tenant
Write-LogOutput "`nAuthenticating to tenant..." "Cyan"
Connect-AzAccount -TenantId $selectedTenant.Id | Out-Null
Write-LogOutput "✅ Successfully connected to Azure" "Green"

Write-LogOutput "`n🔍 Retrieving available subscriptions..." "Cyan"
$subscriptions = Get-AzSubscription
if ($subscriptions.Count -eq 0) {
    Write-LogOutput "❌ No subscriptions found." "Red"
    return
}

# Prompt user to select a subscription
Write-LogOutput "`nAvailable Subscriptions:" "Yellow"
for ($i = 0; $i -lt $subscriptions.Count; $i++) {
    Write-LogOutput "  [$($i + 1)] $($subscriptions[$i].Name) (ID: $($subscriptions[$i].Id))"
}
$subChoice = Read-Host "`nEnter the number of the subscription you want to use"
Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): User selected subscription option: $subChoice"
$selectedSub = $subscriptions[$subChoice - 1]
$subscriptionId = $selectedSub.Id

# Set the active subscription context
Set-AzContext -Subscription $subscriptionId
Write-LogOutput "✅ Selected subscription: $($selectedSub.Name)" "Green"

# Get available resource groups
Write-LogOutput "`n🔍 Retrieving available resource groups..." "Cyan"
$resourceGroups = Get-AzResourceGroup
if ($resourceGroups.Count -eq 0) {
    Write-LogOutput "❌ No resource groups found." "Red"
    return
}

# Prompt user to select a resource group
Write-LogOutput "`nAvailable Resource Groups:" "Yellow"
for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
    Write-LogOutput "  [$($i + 1)] $($resourceGroups[$i].ResourceGroupName) (Location: $($resourceGroups[$i].Location))"
}
$rgChoice = Read-Host "`nEnter the number of the resource group you want to use"
Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): User selected resource group option: $rgChoice"
$selectedRg = $resourceGroups[$rgChoice - 1]
$resourceGroupName = $selectedRg.ResourceGroupName
Write-LogOutput "✅ Selected resource group: $resourceGroupName" "Green"

# Get available virtual networks in the selected resource group
Write-LogOutput "`n🔍 Retrieving available virtual networks in '$resourceGroupName'..." "Cyan"
$virtualNetworks = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName
if ($virtualNetworks.Count -eq 0) {
    Write-LogOutput "❌ No virtual networks found in resource group '$resourceGroupName'." "Red"
    return
}

# Prompt user to select a virtual network
Write-LogOutput "`nAvailable Virtual Networks:" "Yellow"
for ($i = 0; $i -lt $virtualNetworks.Count; $i++) {
    Write-LogOutput "  [$($i + 1)] $($virtualNetworks[$i].Name) (Location: $($virtualNetworks[$i].Location))"
}
$vnetChoice = Read-Host "`nEnter the number of the virtual network you want to use"
Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): User selected virtual network option: $vnetChoice"
$selectedVnet = $virtualNetworks[$vnetChoice - 1]
$virtualNetworkName = $selectedVnet.Name
Write-LogOutput "✅ Selected virtual network: $virtualNetworkName" "Green"

Write-LogOutput "`n========================================" "Cyan"
Write-LogOutput "Starting Windows 365 Permission Checks" "Cyan"
Write-LogOutput "========================================`n" "Cyan"

# Get the Windows 365 Service Principal
try {
    $sp = Get-AzADServicePrincipal -ApplicationId '0af06dc6-e4b5-4f28-818e-e78e62d137a5' -ErrorAction Stop
    Write-LogOutput "Found Windows 365 Service Principal (ID: $($sp.Id))" "Green"
}
catch {
    Write-LogOutput "Error: Could not find the Windows 365 Service Principal." "Red"
    return
}

Write-LogOutput "`n🔍 1. Checking Subscription-Level Permissions..." "Cyan"
$subRoles = Get-AzRoleAssignment -ObjectId $sp.Id -Scope "/subscriptions/$subscriptionId"
if ($subRoles | Where-Object { $_.RoleDefinitionName -eq "Reader" }) {
    Write-LogOutput "  ✅ Success: Found 'Reader' role on the subscription." "Green"
} else {
    Write-LogOutput "  ❌ Failed: Did not find 'Reader' role on the subscription." "Red"
}

Write-LogOutput "`n🔍 2. Checking Resource Group-Level Permissions..." "Cyan"
$rgRoles = Get-AzRoleAssignment -ObjectId $sp.Id -ResourceGroupName $resourceGroupName
if ($rgRoles | Where-Object { $_.RoleDefinitionName -eq "Windows 365 Network Interface Contributor" }) {
    Write-LogOutput "  ✅ Success: Found 'Windows 365 Network Interface Contributor' role on the resource group." "Green"
} else {
    Write-LogOutput "  ❌ Failed: Did not find 'Windows 365 Network Interface Contributor' role on the resource group." "Red"
}

Write-LogOutput "`n🔍 3. Checking Virtual Network-Level Permissions..." "Cyan"
$vnetRoles = Get-AzRoleAssignment -ObjectId $sp.Id -ResourceGroupName $resourceGroupName -ResourceType 'Microsoft.Network/virtualNetworks' -ResourceName $virtualNetworkName
if ($vnetRoles | Where-Object { $_.RoleDefinitionName -eq "Windows 365 Network User" }) {
    Write-LogOutput "  ✅ Success: Found 'Windows 365 Network User' role on the virtual network." "Green"
} else {
    Write-LogOutput "  ❌ Failed: Did not find 'Windows 365 Network User' role on the virtual network." "Red"
}

Write-LogOutput "`n========================================" "Cyan"
Write-LogOutput "Permission check completed successfully!" "Green"
Write-LogOutput "Log saved to: $logPath" "Gray"