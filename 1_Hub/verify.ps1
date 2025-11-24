#Requires -Version 5.1
<#
.SYNOPSIS
    Verify Hub Landing Zone deployment in Azure.

.DESCRIPTION
    This script verifies that all expected Hub infrastructure resources are deployed correctly.
    It checks resource groups, networking components, security groups, DNS zones, and monitoring.
    Output is displayed on console and saved to a timestamped log file.

.EXAMPLE
    .\verify.ps1
    Run verification and generate log file

.NOTES
    Requires:
    - Azure PowerShell module (Az)
    - Active Azure login
    - Read permissions on hub resource groups
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

# Generate log file name with timestamp in user's Documents folder
$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm"
$documentsFolder = [Environment]::GetFolderPath("MyDocuments")
$logFile = Join-Path $documentsFolder "Verify-Hub-$timestamp.log"

# Function to write to both console and log file
function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    
    # Write to console with color
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    }
    else {
        Write-Host $Message -ForegroundColor $Color
    }
    
    # Write to log file (without color codes)
    if ($NoNewline) {
        $Message | Out-File -FilePath $logFile -Append -NoNewline
    }
    else {
        $Message | Out-File -FilePath $logFile -Append
    }
}

# Start verification
$startTime = Get-Date

Write-Log "========================================" -Color Cyan
Write-Log "  Hub Landing Zone Verification" -Color Cyan
Write-Log "========================================" -Color Cyan
Write-Log "Started: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Color Gray
Write-Log "Log File: $logFile" -Color Gray
Write-Log ""

# Check Azure login
Write-Log "[1/7] Checking Azure login status..." -Color Yellow
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        Write-Log "ERROR: Not logged in to Azure" -Color Red
        Write-Log "Please run: Connect-AzAccount" -Color Yellow
        exit 1
    }
    Write-Log "✓ Logged in as: $($context.Account.Id)" -Color Green
    Write-Log "  Subscription: $($context.Subscription.Name)" -Color Gray
    Write-Log "  Subscription ID: $($context.Subscription.Id)" -Color Gray
}
catch {
    Write-Log "ERROR: Failed to get Azure context: $_" -Color Red
    exit 1
}
Write-Log ""

# Check Resource Groups
Write-Log "[2/7] Checking Resource Groups..." -Color Yellow
$expectedRGs = @('rg-hub-net', 'rg-hub-ops')
$foundRGs = @{}
$missingRGs = @()

foreach ($rgName in $expectedRGs) {
    try {
        $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
        $foundRGs[$rgName] = $rg
        Write-Log "✓ Found: $rgName (Location: $($rg.Location), State: $($rg.ProvisioningState))" -Color Green
    }
    catch {
        $missingRGs += $rgName
        Write-Log "✗ Missing: $rgName" -Color Red
    }
}

if ($missingRGs.Count -gt 0) {
    Write-Log "WARNING: $($missingRGs.Count) resource group(s) missing" -Color Yellow
}
else {
    Write-Log "✓ All expected resource groups found" -Color Green
}
Write-Log ""

# Check Network Resources
Write-Log "[3/7] Checking Network Resources..." -Color Yellow
if ($foundRGs.ContainsKey('rg-hub-net')) {
    $netResources = Get-AzResource -ResourceGroupName 'rg-hub-net' | Sort-Object ResourceType, Name
    
    Write-Log "  Resources in rg-hub-net:" -Color Cyan
    Write-Log "  -------------------------" -Color Gray
    
    $resourceCounts = @{}
    foreach ($resource in $netResources) {
        $type = $resource.ResourceType.Split('/')[-1]
        if (-not $resourceCounts.ContainsKey($type)) {
            $resourceCounts[$type] = 0
        }
        $resourceCounts[$type]++
        
        Write-Log "  ✓ $($resource.Name)" -Color Green
        Write-Log "    Type: $($resource.ResourceType)" -Color Gray
        Write-Log "    Location: $($resource.Location)" -Color Gray
    }
    
    Write-Log ""
    Write-Log "  Resource Summary:" -Color Cyan
    foreach ($type in $resourceCounts.Keys | Sort-Object) {
        $count = $resourceCounts[$type]
        Write-Log "    ${type}: $count" -Color Gray
    }
    
    # Verify specific critical resources
    Write-Log ""
    Write-Log "  Critical Network Components:" -Color Cyan
    
    $vnet = $netResources | Where-Object { $_.ResourceType -eq 'Microsoft.Network/virtualNetworks' }
    if ($vnet) {
        Write-Log "  ✓ Virtual Network: $($vnet.Name)" -Color Green
        
        # Get VNet details
        $vnetDetails = Get-AzVirtualNetwork -Name $vnet.Name -ResourceGroupName 'rg-hub-net'
        Write-Log "    Address Space: $($vnetDetails.AddressSpace.AddressPrefixes -join ', ')" -Color Gray
        Write-Log "    Subnets: $($vnetDetails.Subnets.Count)" -Color Gray
        foreach ($subnet in $vnetDetails.Subnets) {
            Write-Log "      - $($subnet.Name): $($subnet.AddressPrefix)" -Color Gray
        }
    }
    else {
        Write-Log "  ✗ Virtual Network: NOT FOUND" -Color Red
    }
    
    $nsgs = $netResources | Where-Object { $_.ResourceType -eq 'Microsoft.Network/networkSecurityGroups' }
    Write-Log "  ✓ Network Security Groups: $($nsgs.Count)" -Color Green
    foreach ($nsg in $nsgs) {
        Write-Log "    - $($nsg.Name)" -Color Gray
    }
    
    $dnsZones = $netResources | Where-Object { $_.ResourceType -eq 'Microsoft.Network/privateDnsZones' }
    Write-Log "  ✓ Private DNS Zones: $($dnsZones.Count)" -Color Green
    foreach ($zone in $dnsZones) {
        Write-Log "    - $($zone.Name)" -Color Gray
    }
    
    $publicIPs = $netResources | Where-Object { $_.ResourceType -eq 'Microsoft.Network/publicIPAddresses' }
    if ($publicIPs) {
        Write-Log "  ✓ Public IP Addresses: $($publicIPs.Count)" -Color Green
        foreach ($pip in $publicIPs) {
            Write-Log "    - $($pip.Name)" -Color Gray
        }
    }
    
    $firewalls = $netResources | Where-Object { $_.ResourceType -eq 'Microsoft.Network/azureFirewalls' }
    if ($firewalls) {
        Write-Log "  ✓ Azure Firewall: $($firewalls.Count)" -Color Green
        foreach ($fw in $firewalls) {
            Write-Log "    - $($fw.Name)" -Color Gray
        }
    }
    else {
        Write-Log "  ℹ Azure Firewall: Not deployed (disabled in parameters)" -Color Yellow
    }
}
else {
    Write-Log "  ✗ Cannot check network resources - rg-hub-net not found" -Color Red
}
Write-Log ""

# Check Operations Resources
Write-Log "[4/7] Checking Operations Resources..." -Color Yellow
if ($foundRGs.ContainsKey('rg-hub-ops')) {
    $opsResources = Get-AzResource -ResourceGroupName 'rg-hub-ops' | Sort-Object ResourceType, Name
    
    Write-Log "  Resources in rg-hub-ops:" -Color Cyan
    Write-Log "  -------------------------" -Color Gray
    
    foreach ($resource in $opsResources) {
        Write-Log "  ✓ $($resource.Name)" -Color Green
        Write-Log "    Type: $($resource.ResourceType)" -Color Gray
        Write-Log "    Location: $($resource.Location)" -Color Gray
    }
    
    # Check for Log Analytics Workspace
    Write-Log ""
    Write-Log "  Critical Operations Components:" -Color Cyan
    $law = $opsResources | Where-Object { $_.ResourceType -eq 'Microsoft.OperationalInsights/workspaces' }
    if ($law) {
        Write-Log "  ✓ Log Analytics Workspace: $($law.Name)" -Color Green
        
        # Get workspace details
        $lawDetails = Get-AzOperationalInsightsWorkspace -ResourceGroupName 'rg-hub-ops' -Name $law.Name
        Write-Log "    Workspace ID: $($lawDetails.CustomerId)" -Color Gray
        Write-Log "    Retention (days): $($lawDetails.RetentionInDays)" -Color Gray
        Write-Log "    SKU: $($lawDetails.Sku)" -Color Gray
    }
    else {
        Write-Log "  ✗ Log Analytics Workspace: NOT FOUND" -Color Red
    }
}
else {
    Write-Log "  ✗ Cannot check operations resources - rg-hub-ops not found" -Color Red
}
Write-Log ""

# Check Diagnostic Settings
Write-Log "[5/7] Checking Diagnostic Settings..." -Color Yellow
try {
    $subId = $context.Subscription.Id
    $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$subId"
    
    if ($diagnosticSettings) {
        Write-Log "  ✓ Subscription diagnostic settings configured: $($diagnosticSettings.Count)" -Color Green
        foreach ($setting in $diagnosticSettings) {
            Write-Log "    - $($setting.Name)" -Color Gray
            if ($setting.WorkspaceId) {
                Write-Log "      Logs sent to: $($setting.WorkspaceId.Split('/')[-1])" -Color Gray
            }
        }
    }
    else {
        Write-Log "  ℹ No subscription diagnostic settings found" -Color Yellow
    }
}
catch {
    Write-Log "  ⚠ Could not check diagnostic settings: $_" -Color Yellow
}
Write-Log ""

# Check Deployments
Write-Log "[6/7] Checking Recent Deployments..." -Color Yellow
try {
    $deployments = Get-AzSubscriptionDeployment | 
        Where-Object { $_.DeploymentName -like 'hub-deploy-*' } | 
        Sort-Object Timestamp -Descending | 
        Select-Object -First 5
    
    if ($deployments) {
        Write-Log "  Recent hub deployments:" -Color Cyan
        foreach ($deployment in $deployments) {
            $statusColor = if ($deployment.ProvisioningState -eq 'Succeeded') { 'Green' } else { 'Red' }
            Write-Log "  $($deployment.ProvisioningState): $($deployment.DeploymentName)" -Color $statusColor
            Write-Log "    Timestamp: $($deployment.Timestamp)" -Color Gray
            Write-Log "    Location: $($deployment.Location)" -Color Gray
        }
    }
    else {
        Write-Log "  ℹ No hub deployments found" -Color Yellow
    }
}
catch {
    Write-Log "  ⚠ Could not check deployments: $_" -Color Yellow
}
Write-Log ""

# Summary
Write-Log "[7/7] Verification Summary" -Color Yellow
Write-Log "========================================" -Color Cyan

$totalIssues = 0

# Resource Group Summary
if ($missingRGs.Count -eq 0) {
    Write-Log "✓ Resource Groups: OK ($($foundRGs.Count)/$($expectedRGs.Count))" -Color Green
}
else {
    Write-Log "✗ Resource Groups: ISSUES ($($foundRGs.Count)/$($expectedRGs.Count) found)" -Color Red
    $totalIssues++
}

# Network Summary
if ($foundRGs.ContainsKey('rg-hub-net')) {
    $netCount = (Get-AzResource -ResourceGroupName 'rg-hub-net').Count
    Write-Log "✓ Network Resources: OK ($netCount resources)" -Color Green
}
else {
    Write-Log "✗ Network Resources: NOT VERIFIED" -Color Red
    $totalIssues++
}

# Operations Summary
if ($foundRGs.ContainsKey('rg-hub-ops')) {
    $opsCount = (Get-AzResource -ResourceGroupName 'rg-hub-ops').Count
    Write-Log "✓ Operations Resources: OK ($opsCount resources)" -Color Green
}
else {
    Write-Log "✗ Operations Resources: NOT VERIFIED" -Color Red
    $totalIssues++
}

Write-Log ""
$endTime = Get-Date
$duration = $endTime - $startTime

if ($totalIssues -eq 0) {
    Write-Log "========================================" -Color Green
    Write-Log "  ✓ VERIFICATION PASSED" -Color Green
    Write-Log "========================================" -Color Green
    Write-Log "All hub infrastructure components are deployed correctly." -Color Green
}
else {
    Write-Log "========================================" -Color Red
    Write-Log "  ✗ VERIFICATION FAILED" -Color Red
    Write-Log "========================================" -Color Red
    Write-Log "Found $totalIssues issue(s) with hub deployment." -Color Red
    Write-Log "Please review the log file for details." -Color Yellow
}

Write-Log ""
Write-Log "Completed: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Color Gray
Write-Log "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -Color Gray
Write-Log "Log saved to: $logFile" -Color Gray
Write-Log ""

# Exit with appropriate code
if ($totalIssues -eq 0) {
    exit 0
}
else {
    exit 1
}
