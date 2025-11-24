#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy Windows 365 Spoke Network infrastructure to Azure.

.DESCRIPTION
    This script deploys a Windows 365 spoke network using Bicep templates.
    It creates a resource group and virtual network with subnets optimized for Windows 365 Cloud PCs.

.PARAMETER WhatIf
    Preview the changes without actually deploying.

.PARAMETER Validate
    Validate the template without deploying.

.PARAMETER Location
    Azure region for deployment. Default: westus3

.PARAMETER TenantId
    Optional Azure AD tenant ID to target. Overrides the interactive tenant picker when supplied.

.PARAMETER SubscriptionId
    Optional subscription ID within the selected tenant. When omitted the script will prompt if multiple subscriptions exist.

.PARAMETER StudentNumber
    Student number (1-40) for unique IP addressing. Each student gets a unique /24 network: 192.168.X.0/24 where X = StudentNumber.
    Default: 1

.PARAMETER Force
    Forces clearing of all cached Azure credentials before authentication.
    Use this if you're being redirected to the wrong tenant or need to log in with different credentials.

.EXAMPLE
    .\deploy.ps1
    Deploy the infrastructure for student 1

.EXAMPLE
    .\deploy.ps1 -StudentNumber 5
    Deploy the infrastructure for student 5 (uses 192.168.5.0/24)

.EXAMPLE
    .\deploy.ps1 -Force
    Clear cached credentials and deploy with fresh authentication

.EXAMPLE
    .\deploy.ps1 -Force -StudentNumber 3
    Clear credentials and deploy for student 3

.EXAMPLE
    .\deploy.ps1 -Validate
    Validate the template only

.EXAMPLE
    .\deploy.ps1 -WhatIf
    Preview changes before deployment

.EXAMPLE
    .\deploy.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -SubscriptionId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" -StudentNumber 10
    Deploy using explicit tenant and subscription without interactive prompts for student 10

.NOTES
    Requires:
    - Azure PowerShell module (Az)
    - Bicep CLI
    - Network Contributor role OR Contributor role at subscription level
    - Permission to create resource groups
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$Validate,

    [Parameter(Mandatory = $false)]
    [string]$Location = "southcentralus",

    [Parameter(Mandatory = $false)]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 40)]
    [int]$StudentNumber = 1,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Script variables
$ScriptPath = $PSScriptRoot
$TemplateFile = Join-Path $ScriptPath "infra\envs\prod\main.bicep"
$TemplateJsonFile = Join-Path $ScriptPath "infra\envs\prod\main.json"
$ParametersFile = Join-Path $ScriptPath "infra\envs\prod\parameters.prod.json"
$DeploymentName = "w365-spoke-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$ResolvedTemplateFile = $TemplateJsonFile

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Windows 365 Spoke Network Deployment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Prompt for student number if not provided
if (-not $PSBoundParameters.ContainsKey('StudentNumber')) {
    Write-Host "`n" -NoNewline
    do {
        $studentInput = Read-Host "Enter Student Number (1-40)"
        $studentNumberInt = 0
        $isValid = [int]::TryParse($studentInput, [ref]$studentNumberInt) -and $studentNumberInt -ge 1 -and $studentNumberInt -le 40
        
        if (-not $isValid) {
            Write-Host "Invalid input. Please enter a number between 1 and 40." -ForegroundColor Yellow
        }
    } while (-not $isValid)
    
    $StudentNumber = $studentNumberInt
    Write-Host "Selected Student Number: $StudentNumber" -ForegroundColor Green
    Write-Host "VNet Address Space: 192.168.$StudentNumber.0/24" -ForegroundColor Cyan
}
else {
    Write-Host "`nStudent Number: $StudentNumber (from parameter)" -ForegroundColor Green
    Write-Host "VNet Address Space: 192.168.$StudentNumber.0/24" -ForegroundColor Cyan
}

# Function to test if Az module is installed
function Test-AzModuleInstalled {
    Write-Host "`n[1/6] Checking Azure PowerShell module..." -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
        Write-Host "ERROR: Azure PowerShell module (Az) is not installed." -ForegroundColor Red
        Write-Host "Install it with: Install-Module -Name Az -Repository PSGallery -Force" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✓ Az module is installed" -ForegroundColor Green
}

# Function to select tenant and subscription context
function Select-AzureTenantContext {
    param(
        [string]$TenantId,
        [string]$SubscriptionId,
        [switch]$ForceLogin
    )

    Write-Host "`n[2/6] Establishing Azure context..." -ForegroundColor Yellow

    try {
        # Clear all cached credentials if Force is specified
        if ($ForceLogin) {
            Write-Host "  Force login requested - clearing all Azure credentials..." -ForegroundColor Yellow
            try {
                Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
                Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null
                Write-Host "  All cached credentials cleared" -ForegroundColor Green
            }
            catch {
                Write-Host "  Note: Some credentials may still be cached" -ForegroundColor Yellow
            }
        }

        $context = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $context) {
            Write-Host "  Not logged in to Azure. Initiating login..." -ForegroundColor Yellow
            Connect-AzAccount | Out-Null
            $context = Get-AzContext
        }

        Write-Host "  Signed in as: $($context.Account.Id)" -ForegroundColor Green

        Write-Host "`n  Retrieving accessible tenants..." -ForegroundColor Yellow
        $tenants = @(Get-AzTenant)

        if ($tenants.Count -eq 0) {
            Write-Host "ERROR: No accessible tenants found for this account." -ForegroundColor Red
            return $false
        }

        $selectedTenant = $null

        if ($TenantId) {
            $selectedTenant = $tenants | Where-Object { $_.Id -eq $TenantId }
            if (-not $selectedTenant) {
                Write-Host "ERROR: Specified tenant ID '$TenantId' is not accessible." -ForegroundColor Red
                return $false
            }
            Write-Host "  Using specified tenant: $($selectedTenant.Name) ($($selectedTenant.Id))" -ForegroundColor Green
        }
        elseif ($tenants.Count -eq 1) {
            $selectedTenant = $tenants[0]
            Write-Host "  Single tenant detected: $($selectedTenant.Name) ($($selectedTenant.Id))" -ForegroundColor Green
        }
        else {
            Write-Host "  Available Tenants:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $tenants.Count; $i++) {
                $tenant = $tenants[$i]
                Write-Host "    [$($i + 1)] $($tenant.Name) ($($tenant.Id))" -ForegroundColor Gray
            }

            do {
                $selection = Read-Host "  Select tenant number (1-$($tenants.Count))"
                $selectionIndex = [int]$selection - 1
            } while ($selectionIndex -lt 0 -or $selectionIndex -ge $tenants.Count)

            $selectedTenant = $tenants[$selectionIndex]
            Write-Host "  Selected tenant: $($selectedTenant.Name) ($($selectedTenant.Id))" -ForegroundColor Green
        }

        Write-Host "`n  Authenticating to tenant..." -ForegroundColor Yellow
        try {
            Connect-AzAccount -TenantId $selectedTenant.Id -ErrorAction Stop | Out-Null
            Write-Host "  Authentication successful." -ForegroundColor Green
        }
        catch {
            Write-Host "ERROR: Failed to authenticate to tenant '$($selectedTenant.Name)'." -ForegroundColor Red
            Write-Host "If MFA is required, run: Connect-AzAccount -TenantId $($selectedTenant.Id)" -ForegroundColor Yellow
            Write-Host "Then rerun this script with: .\\deploy.ps1 -TenantId $($selectedTenant.Id)" -ForegroundColor Yellow
            return $false
        }

        Write-Host "`n  Retrieving subscriptions..." -ForegroundColor Yellow
        try {
            $subscriptions = @(Get-AzSubscription -TenantId $selectedTenant.Id -WarningAction SilentlyContinue -ErrorAction Stop | Where-Object { $_.State -eq "Enabled" })
        }
        catch {
            Write-Host "ERROR: Unable to enumerate subscriptions for tenant '$($selectedTenant.Name)'." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            return $false
        }

        if ($subscriptions.Count -eq 0) {
            Write-Host "ERROR: No enabled subscriptions found in tenant '$($selectedTenant.Name)'." -ForegroundColor Red
            Write-Host "Verify your access or choose a different tenant." -ForegroundColor Yellow
            return $false
        }

        $selectedSubscription = $null

        if ($SubscriptionId) {
            $selectedSubscription = $subscriptions | Where-Object { $_.Id -eq $SubscriptionId }
            if (-not $selectedSubscription) {
                Write-Host "ERROR: Subscription '$SubscriptionId' not found in tenant '$($selectedTenant.Name)'." -ForegroundColor Red
                return $false
            }
            Write-Host "  Using specified subscription: $($selectedSubscription.Name) ($($selectedSubscription.Id))" -ForegroundColor Green
        }
        elseif ($subscriptions.Count -eq 1) {
            $selectedSubscription = $subscriptions[0]
            Write-Host "  Single subscription detected: $($selectedSubscription.Name) ($($selectedSubscription.Id))" -ForegroundColor Green
        }
        else {
            Write-Host "  Available Subscriptions:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                $sub = $subscriptions[$i]
                Write-Host "    [$($i + 1)] $($sub.Name) ($($sub.Id))" -ForegroundColor Gray
            }

            do {
                $selection = Read-Host "  Select subscription number (1-$($subscriptions.Count))"
                $selectionIndex = [int]$selection - 1
            } while ($selectionIndex -lt 0 -or $selectionIndex -ge $subscriptions.Count)

            $selectedSubscription = $subscriptions[$selectionIndex]
            Write-Host "  Selected subscription: $($selectedSubscription.Name) ($($selectedSubscription.Id))" -ForegroundColor Green
        }

        Write-Host "`n  Switching Azure context..." -ForegroundColor Yellow
        $newContext = Set-AzContext -TenantId $selectedTenant.Id -SubscriptionId $selectedSubscription.Id -ErrorAction Stop

        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host " Active Azure Context" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host " Account:      $($newContext.Account.Id)" -ForegroundColor Gray
        Write-Host " Tenant:       $($newContext.Tenant.Id)" -ForegroundColor Gray
        Write-Host " Subscription: $($newContext.Subscription.Name)" -ForegroundColor Gray
        Write-Host "               $($newContext.Subscription.Id)" -ForegroundColor Gray
        Write-Host "========================================" -ForegroundColor Cyan

        return $true
    }
    catch {
        Write-Host "ERROR: Failed to establish Azure context." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

# Function to check if files exist
function Test-DeploymentFiles {
    Write-Host "`n[3/6] Validating deployment files..." -ForegroundColor Yellow
    
    if (-not (Test-Path $TemplateFile)) {
        Write-Host "ERROR: Template file not found: $TemplateFile" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Bicep template found: $TemplateFile" -ForegroundColor Green
    
    if (-not (Test-Path $ParametersFile)) {
        Write-Host "ERROR: Parameters file not found: $ParametersFile" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Parameters file found: $ParametersFile" -ForegroundColor Green
}

# Function to build Bicep to ARM JSON
function Build-BicepTemplate {
    Write-Host "`n[4/6] Building Bicep template to ARM JSON..." -ForegroundColor Yellow

    # Check if Bicep CLI is available
    try {
        $bicepVersion = az bicep version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Bicep CLI version: $bicepVersion" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "WARNING: Bicep CLI not found. Install with: az bicep install" -ForegroundColor Yellow
        Write-Host "Attempting deployment with .bicep file directly..." -ForegroundColor Yellow
        $script:ResolvedTemplateFile = $TemplateFile
        return
    }

    # Build the template
    try {
        Write-Host "  Building: $TemplateFile" -ForegroundColor Gray
        az bicep build --file $TemplateFile --outfile $TemplateJsonFile 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Bicep template compiled successfully" -ForegroundColor Green
            Write-Host "  Output: $TemplateJsonFile" -ForegroundColor Gray
            $script:ResolvedTemplateFile = $TemplateJsonFile
        }
        else {
            Write-Host "WARNING: Bicep compilation failed. Falling back to .bicep file." -ForegroundColor Yellow
            $script:ResolvedTemplateFile = $TemplateFile
        }
    }
    catch {
        Write-Host "WARNING: Failed to build Bicep template: $_" -ForegroundColor Yellow
        Write-Host "Continuing with .bicep file." -ForegroundColor Yellow
        $script:ResolvedTemplateFile = $TemplateFile
    }
}

# Function to validate deployment
function Test-Deployment {
    Write-Host "`n[5/6] Validating deployment template..." -ForegroundColor Yellow
    Write-Host "  Student Number: $StudentNumber" -ForegroundColor Gray
    Write-Host "  VNet Address Space: 192.168.$StudentNumber.0/24" -ForegroundColor Gray
    
    try {
        # Get Windows 365 service principal ID for validation
        $w365SpId = Get-Windows365ServicePrincipal
        if (-not $w365SpId) {
            Write-Host "  WARNING: Windows 365 service principal not found - validation may fail" -ForegroundColor Yellow
            # Use a placeholder GUID for validation purposes
            $w365SpId = '00000000-0000-0000-0000-000000000000'
        }
        
        # Load base parameters from file
        $paramsContent = Get-Content $ParametersFile | ConvertFrom-Json
        $templateParams = @{}
        
        # Convert parameters to hashtable
        foreach ($param in $paramsContent.parameters.PSObject.Properties) {
            $templateParams[$param.Name] = $param.Value.value
        }
        
        # Override/add required parameters
        $templateParams['studentNumber'] = $StudentNumber
        $templateParams['windows365ServicePrincipalId'] = $w365SpId
        
        $null = Test-AzSubscriptionDeployment `
            -Location $Location `
            -TemplateFile $ResolvedTemplateFile `
            -TemplateParameterObject $templateParams `
            -ErrorAction Stop
        
        Write-Host "✓ Validation successful! No errors found in the template." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "ERROR: Template validation failed!" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        if ($_.Exception.InnerException) {
            Write-Host $_.Exception.InnerException.Message -ForegroundColor Red
        }
        return $false
    }
}

# Function to check VNet quota
function Test-VNetQuota {
    param([string]$ResourceGroupName)
    
    Write-Host "`nChecking VNet quota (max: 1)..." -ForegroundColor Yellow
    
    try {
        # Get resource group
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-Host "  Resource group doesn't exist yet - quota check passed" -ForegroundColor Green
            return $true
        }
        
        # Count existing VNets
        $existingVNets = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        $vnetCount = ($existingVNets | Measure-Object).Count
        
        Write-Host "  Current VNets: $vnetCount" -ForegroundColor Gray
        
        if ($vnetCount -ge 1) {
            Write-Host "`n══════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host "ERROR: VNet quota exceeded!" -ForegroundColor Red
            Write-Host "══════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host "" -ForegroundColor Red
            Write-Host "Maximum allowed: 1 VNet per resource group" -ForegroundColor Red
            Write-Host "Current count: $vnetCount" -ForegroundColor Red
            Write-Host "`nExisting VNets:" -ForegroundColor Yellow
            $existingVNets | ForEach-Object {
                Write-Host "  - $($_.Name) ($($_.AddressSpace.AddressPrefixes -join ', '))" -ForegroundColor Yellow
            }
            Write-Host "`nYou must delete the existing VNet before creating a new one." -ForegroundColor Yellow
            Write-Host "Command: Remove-AzVirtualNetwork -Name <vnet-name> -ResourceGroupName $ResourceGroupName -Force" -ForegroundColor Cyan
            Write-Host "" -ForegroundColor Red
            
            return $false
        }
        
        Write-Host "  VNet quota check passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "WARNING: Quota check failed - $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Continuing with deployment..." -ForegroundColor Yellow
        return $true  # Don't block deployment on check failure
    }
}

# Function to get Windows 365 service principal
function Get-Windows365ServicePrincipal {
    Write-Host "`n[5/6] Retrieving Windows 365 service principal..." -ForegroundColor Yellow
    
    try {
        # Windows 365 application ID (constant across all tenants)
        $w365AppId = '0af06dc6-e4b5-4f28-818e-e78e62d137a5'
        
        $sp = Get-AzADServicePrincipal -ApplicationId $w365AppId -ErrorAction Stop
        
        if ($sp) {
            Write-Host "  ✓ Found Windows 365 service principal (Object ID: $($sp.Id))" -ForegroundColor Green
            return $sp.Id
        }
        else {
            Write-Host "  ERROR: Windows 365 service principal not found in this tenant." -ForegroundColor Red
            Write-Host "  This service principal should exist automatically in tenants with Windows 365 licenses." -ForegroundColor Yellow
            Write-Host "  Application ID: $w365AppId" -ForegroundColor Gray
            return $null
        }
    }
    catch {
        Write-Host "  ERROR: Failed to retrieve Windows 365 service principal." -ForegroundColor Red
        Write-Host "  $_" -ForegroundColor Red
        return $null
    }
}

# Function to deploy
function Start-Deployment {
    Write-Host "`n[6/6] Starting deployment..." -ForegroundColor Yellow
    Write-Host "  Deployment Name: $DeploymentName" -ForegroundColor Gray
    Write-Host "  Location: $Location" -ForegroundColor Gray
    Write-Host "  Scope: Subscription" -ForegroundColor Gray
    Write-Host "  Student Number: $StudentNumber" -ForegroundColor Cyan
    Write-Host "  VNet Address: 192.168.$StudentNumber.0/24" -ForegroundColor Cyan
    Write-Host "    - Cloud PC Subnet: 192.168.$StudentNumber.0/26" -ForegroundColor Gray
    Write-Host "    - Management Subnet: 192.168.$StudentNumber.64/26" -ForegroundColor Gray
    Write-Host "    - AVD Subnet: 192.168.$StudentNumber.128/26" -ForegroundColor Gray
    
    try {
        # Check VNet quota for student spoke resource group
        $expectedRgName = "rg-w365-spoke-student$StudentNumber-prod"
        Write-Host "`nEnforcing resource quota for student lab environment..." -ForegroundColor Yellow
        if (-not (Test-VNetQuota -ResourceGroupName $expectedRgName)) {
            throw "VNet quota exceeded. Cannot proceed with deployment."
        }
        
        # Get Windows 365 service principal ID
        $w365SpId = Get-Windows365ServicePrincipal
        if (-not $w365SpId) {
            Write-Host "`nERROR: Cannot proceed without Windows 365 service principal." -ForegroundColor Red
            Write-Host "Ensure your tenant has Windows 365 licenses provisioned." -ForegroundColor Yellow
            exit 1
        }
        
        # Load base parameters from file
        $paramsContent = Get-Content $ParametersFile | ConvertFrom-Json
        $templateParams = @{}
        
        # Convert parameters to hashtable
        foreach ($param in $paramsContent.parameters.PSObject.Properties) {
            $templateParams[$param.Name] = $param.Value.value
        }
        
        # Override/add required parameters
        $templateParams['studentNumber'] = $StudentNumber
        $templateParams['windows365ServicePrincipalId'] = $w365SpId
        
        # Display parameters being passed to deployment
        Write-Host "`n  Deployment Parameters:" -ForegroundColor Yellow
        Write-Host "    Student Number: $($templateParams['studentNumber'])" -ForegroundColor Gray
        Write-Host "    Expected Resource Group: rg-w365-spoke-student$($templateParams['studentNumber'])-$($templateParams['env'])" -ForegroundColor Gray
        Write-Host "    Expected VNet: vnet-w365-spoke-student$($templateParams['studentNumber'])-$($templateParams['env'])" -ForegroundColor Gray
        
        if ($WhatIf) {
            Write-Host "`n=== WHAT-IF MODE - No changes will be made ===" -ForegroundColor Magenta
            $deployment = New-AzSubscriptionDeployment `
                -Name $DeploymentName `
                -Location $Location `
                -TemplateFile $ResolvedTemplateFile `
                -TemplateParameterObject $templateParams `
                -WhatIf `
                -ErrorAction Stop
        }
        else {
            $deployment = New-AzSubscriptionDeployment `
                -Name $DeploymentName `
                -Location $Location `
                -TemplateFile $ResolvedTemplateFile `
                -TemplateParameterObject $templateParams `
                -ErrorAction Stop
            
            Write-Host "`n========================================" -ForegroundColor Green
            Write-Host "✓ DEPLOYMENT SUCCESSFUL" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "`nDeployment Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($deployment.DeploymentName)" -ForegroundColor Gray
            Write-Host "  Provisioning State: $($deployment.ProvisioningState)" -ForegroundColor Gray
            Write-Host "  Timestamp: $($deployment.Timestamp)" -ForegroundColor Gray
            
            if ($deployment.Outputs.Count -gt 0) {
                Write-Host "`nOutputs:" -ForegroundColor Cyan
                foreach ($output in $deployment.Outputs.GetEnumerator()) {
                    Write-Host "  $($output.Key): $($output.Value.Value)" -ForegroundColor Gray
                }
            }
        }
    }
    catch {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "✗ DEPLOYMENT FAILED" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "`nError Details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        
        if ($_.Exception.InnerException) {
            Write-Host "`nInner Exception:" -ForegroundColor Red
            Write-Host $_.Exception.InnerException.Message -ForegroundColor Red
        }
        
        Write-Host "`nStack Trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        
        exit 1
    }
}

# Main execution
try {
    Test-AzModuleInstalled
    
    if ($Force) {
        Write-Host "`n⚠️  Force mode enabled - clearing all cached credentials" -ForegroundColor Yellow
    }
    
    if (-not (Select-AzureTenantContext -TenantId $TenantId -SubscriptionId $SubscriptionId -ForceLogin:$Force)) {
        exit 1
    }
    Test-DeploymentFiles
    Build-BicepTemplate
    
    if ($Validate) {
        $isValid = Test-Deployment
        if ($isValid) {
            Write-Host "`n========================================" -ForegroundColor Green
            Write-Host "✓ VALIDATION SUCCESSFUL" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "`nThe template is valid and ready for deployment." -ForegroundColor Green
            Write-Host "Run without -Validate flag to deploy." -ForegroundColor Yellow
        }
        else {
            exit 1
        }
    }
    else {
        $isValid = Test-Deployment
        if (-not $isValid) {
            Write-Host "`nDeployment aborted due to validation errors." -ForegroundColor Red
            exit 1
        }
        Start-Deployment
    }
}
catch {
    Write-Host "`nUnexpected error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
