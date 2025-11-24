<#
.SYNOPSIS
    Deploy Hub Landing Zone using Azure PowerShell
.DESCRIPTION
    This script deploys the minimal hub landing zone infrastructure using Azure PowerShell cmdlets.
    It provides a more reliable alternative to Azure CLI for deployments.
    Supports multi-tenant scenarios for administrators with guest access to multiple tenants.
.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -WhatIf
    .\deploy.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    .\deploy.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -SubscriptionId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Validate,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westus3",
    
    [Parameter(Mandatory=$false)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
if (!$ScriptRoot) { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$TemplateFile = Join-Path $ScriptRoot "infra\envs\prod\main.bicep"
$ParametersFile = Join-Path $ScriptRoot "infra\envs\prod\parameters.prod.json"
$DeploymentName = "hub-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Ensure Bicep is in PATH
$bicepPath = "$env:USERPROFILE\.bicep"
if ((Test-Path "$bicepPath\bicep.exe") -and ($env:Path -notlike "*$bicepPath*")) {
    $env:Path += ";$bicepPath"
}

# Function to check if Az module is installed
function Test-AzModuleInstalled {
    Write-Host "`nChecking for Azure PowerShell module..." -ForegroundColor Cyan
    
    if (!(Get-Module -ListAvailable -Name Az.Resources)) {
        Write-Host "Azure PowerShell module not found!" -ForegroundColor Red
        Write-Host "Please install it using: Install-Module -Name Az -Repository PSGallery -Force" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "Azure PowerShell module found." -ForegroundColor Green
    return $true
}

# Function to select tenant and establish context
function Select-AzureTenantContext {
    param(
        [string]$TenantId,
        [string]$SubscriptionId
    )
    
    Write-Host "`nChecking Azure login status..." -ForegroundColor Cyan
    
    try {
        # Ensure user is authenticated
        $context = Get-AzContext
        if (!$context) {
            Write-Host "Not logged in to Azure. Initiating login..." -ForegroundColor Yellow
            Connect-AzAccount -Force
            $context = Get-AzContext
        }
        
        Write-Host "Logged in as: $($context.Account.Id)" -ForegroundColor Green
        
        # Get all available tenants
        Write-Host "`nRetrieving available tenants..." -ForegroundColor Cyan
        $tenants = Get-AzTenant
        
        if ($tenants.Count -eq 0) {
            Write-Host "No accessible tenants found." -ForegroundColor Red
            return $false
        }
        
        # Select tenant
        $selectedTenant = $null
        
        if ($TenantId) {
            # Use explicitly specified tenant
            $selectedTenant = $tenants | Where-Object { $_.Id -eq $TenantId }
            if (!$selectedTenant) {
                Write-Host "Specified tenant ID '$TenantId' not found or not accessible." -ForegroundColor Red
                return $false
            }
            Write-Host "Using specified tenant: $($selectedTenant.Name) ($($selectedTenant.Id))" -ForegroundColor Green
            
            # Re-authenticate to ensure proper access
            Write-Host "`nAuthenticating to tenant..." -ForegroundColor Cyan
            try {
                Connect-AzAccount -TenantId $selectedTenant.Id -Force -ErrorAction Stop | Out-Null
                Write-Host "Successfully authenticated to tenant." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to authenticate to tenant: $_" -ForegroundColor Red
                Write-Host "Please ensure you have access to this tenant and complete any required MFA." -ForegroundColor Yellow
                return $false
            }
        }
        elseif ($tenants.Count -eq 1) {
            # Only one tenant available, use it automatically
            $selectedTenant = $tenants[0]
            Write-Host "Using tenant: $($selectedTenant.Name) ($($selectedTenant.Id))" -ForegroundColor Green
            
            # Re-authenticate to ensure proper access
            Write-Host "`nAuthenticating to tenant..." -ForegroundColor Cyan
            try {
                Connect-AzAccount -TenantId $selectedTenant.Id -Force -ErrorAction Stop | Out-Null
                Write-Host "Successfully authenticated to tenant." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to authenticate to tenant: $_" -ForegroundColor Red
                Write-Host "Please ensure you have access to this tenant and complete any required MFA." -ForegroundColor Yellow
                return $false
            }
        }
        else {
            # Multiple tenants available, prompt for selection
            Write-Host "`nAvailable Tenants:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $tenants.Count; $i++) {
                $tenant = $tenants[$i]
                Write-Host "  [$($i + 1)] $($tenant.Name) ($($tenant.Id))" -ForegroundColor White
            }
            
            do {
                $selection = Read-Host "`nSelect tenant number (1-$($tenants.Count))"
                $selectionIndex = [int]$selection - 1
            } while ($selectionIndex -lt 0 -or $selectionIndex -ge $tenants.Count)
            
            $selectedTenant = $tenants[$selectionIndex]
            Write-Host "Selected tenant: $($selectedTenant.Name) ($($selectedTenant.Id))" -ForegroundColor Green
        }
        
        # Re-authenticate to the selected tenant to ensure proper access (MFA, etc.)
        Write-Host "`nAuthenticating to tenant..." -ForegroundColor Cyan
        try {
            Connect-AzAccount -TenantId $selectedTenant.Id -Force -ErrorAction Stop | Out-Null
            Write-Host "Successfully authenticated to tenant." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to authenticate to tenant: $_" -ForegroundColor Red
            Write-Host "Please ensure you have access to this tenant and complete any required MFA." -ForegroundColor Yellow
            return $false
        }
        
        # Get subscriptions in selected tenant
        Write-Host "`nRetrieving subscriptions in tenant..." -ForegroundColor Cyan
        
        $subscriptions = @()
        try {
            $subscriptions = @(Get-AzSubscription -TenantId $selectedTenant.Id -WarningAction SilentlyContinue -ErrorAction Stop | Where-Object { $_.State -eq "Enabled" })
        }
        catch {
            $errorMessage = $_.Exception.Message
            
            # Check if this is an authentication/MFA error
            if ($errorMessage -match "Authentication failed|User interaction is required|multi-factor authentication") {
                Write-Host "`nAuthentication required for tenant '$($selectedTenant.Name)'." -ForegroundColor Yellow
                Write-Host "This tenant requires additional authentication (possibly MFA)." -ForegroundColor Yellow
                Write-Host "`nTo access this tenant, please run:" -ForegroundColor Cyan
                Write-Host "  Connect-AzAccount -TenantId $($selectedTenant.Id)" -ForegroundColor White
                Write-Host "Then run this script again with:" -ForegroundColor Cyan
                Write-Host "  .\deploy.ps1 -TenantId $($selectedTenant.Id)" -ForegroundColor White
                return $false
            }
            else {
                Write-Host "Failed to retrieve subscriptions: $errorMessage" -ForegroundColor Red
                return $false
            }
        }
        
        if ($subscriptions.Count -eq 0) {
            Write-Host "No accessible subscriptions found in tenant '$($selectedTenant.Name)'." -ForegroundColor Red
            Write-Host "Please ensure you have appropriate access permissions." -ForegroundColor Yellow
            return $false
        }
        
        # Select subscription
        $selectedSubscription = $null
        
        if ($SubscriptionId) {
            # Use explicitly specified subscription
            $selectedSubscription = $subscriptions | Where-Object { $_.Id -eq $SubscriptionId }
            if (!$selectedSubscription) {
                Write-Host "Specified subscription ID '$SubscriptionId' not found in tenant." -ForegroundColor Red
                return $false
            }
            Write-Host "Using specified subscription: $($selectedSubscription.Name) ($($selectedSubscription.Id))" -ForegroundColor Green
        }
        elseif ($subscriptions.Count -eq 1) {
            # Only one subscription available, use it automatically
            $selectedSubscription = $subscriptions[0]
            Write-Host "Using subscription: $($selectedSubscription.Name) ($($selectedSubscription.Id))" -ForegroundColor Green
        }
        else {
            # Multiple subscriptions available, prompt for selection
            Write-Host "`nAvailable Subscriptions:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                $sub = $subscriptions[$i]
                Write-Host "  [$($i + 1)] $($sub.Name) ($($sub.Id))" -ForegroundColor White
            }
            
            do {
                $selection = Read-Host "`nSelect subscription number (1-$($subscriptions.Count))"
                $selectionIndex = [int]$selection - 1
            } while ($selectionIndex -lt 0 -or $selectionIndex -ge $subscriptions.Count)
            
            $selectedSubscription = $subscriptions[$selectionIndex]
            Write-Host "Selected subscription: $($selectedSubscription.Name) ($($selectedSubscription.Id))" -ForegroundColor Green
        }
        
        # Set Azure context to selected tenant and subscription
        Write-Host "`nSwitching to selected context..." -ForegroundColor Cyan
        try {
            # Use Subscription object directly instead of just ID
            $newContext = Set-AzContext -Subscription $selectedSubscription.Id -Tenant $selectedTenant.Id -ErrorAction Stop
            
            if (!$newContext) {
                Write-Host "Failed to set Azure context." -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "Failed to set Azure context: $_" -ForegroundColor Red
            Write-Host "Tenant ID: $($selectedTenant.Id)" -ForegroundColor Yellow
            Write-Host "Subscription ID: $($selectedSubscription.Id)" -ForegroundColor Yellow
            Write-Host "`nTrying alternative method..." -ForegroundColor Yellow
            
            # Alternative: Get current context and verify it matches
            try {
                $currentContext = Get-AzContext
                if ($currentContext.Subscription.Id -eq $selectedSubscription.Id -and $currentContext.Tenant.Id -eq $selectedTenant.Id) {
                    Write-Host "Context is already correctly set." -ForegroundColor Green
                    $newContext = $currentContext
                }
                else {
                    Write-Host "Current context does not match. Please run:" -ForegroundColor Yellow
                    Write-Host "  Connect-AzAccount -TenantId $($selectedTenant.Id) -SubscriptionId $($selectedSubscription.Id)" -ForegroundColor White
                    return $false
                }
            }
            catch {
                Write-Host "Failed to get current context: $_" -ForegroundColor Red
                return $false
            }
        }
        
        # Confirm context
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "  Active Azure Context" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Account:      $($newContext.Account.Id)" -ForegroundColor White
        Write-Host "Tenant:       $($newContext.Tenant.Id)" -ForegroundColor White
        Write-Host "Subscription: $($newContext.Subscription.Name)" -ForegroundColor White
        Write-Host "              $($newContext.Subscription.Id)" -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "Failed to establish Azure context: $_" -ForegroundColor Red
        return $false
    }
}

# Main script execution
try {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Hub Landing Zone Deployment Script" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Check prerequisites
    if (!(Test-AzModuleInstalled)) {
        exit 1
    }
    
    if (!(Select-AzureTenantContext -TenantId $TenantId -SubscriptionId $SubscriptionId)) {
        exit 1
    }
    
    # Verify files exist
    Write-Host "`nVerifying deployment files..." -ForegroundColor Cyan
    
    if (!(Test-Path $TemplateFile)) {
        Write-Host "Template file not found: $TemplateFile" -ForegroundColor Red
        exit 1
    }
    Write-Host "Template file: $TemplateFile" -ForegroundColor Green
    
    if (!(Test-Path $ParametersFile)) {
        Write-Host "Parameters file not found: $ParametersFile" -ForegroundColor Red
        exit 1
    }
    Write-Host "Parameters file: $ParametersFile" -ForegroundColor Green
    
    # Build Bicep to ARM JSON
    Write-Host "`nBuilding Bicep template to ARM JSON..." -ForegroundColor Cyan
    $armTemplateFile = $TemplateFile -replace '\.bicep$', '.json'
    
    try {
        $bicepBuild = az bicep build --file $TemplateFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to build Bicep template. Trying with Azure PowerShell..." -ForegroundColor Yellow
            # If az bicep fails, let PowerShell try to handle it natively
            $armTemplateFile = $TemplateFile
        } else {
            Write-Host "Bicep built successfully: $armTemplateFile" -ForegroundColor Green
            $TemplateFile = $armTemplateFile
        }
    }
    catch {
        Write-Host "Warning: Could not build Bicep with CLI, will try native PowerShell support" -ForegroundColor Yellow
        # Continue with original template file
    }
    
    # Display deployment information
    Write-Host "`nDeployment Configuration:" -ForegroundColor Cyan
    Write-Host "  Name:     $DeploymentName" -ForegroundColor White
    Write-Host "  Location: $Location" -ForegroundColor White
    Write-Host "  Template: $TemplateFile" -ForegroundColor White
    Write-Host "  Parameters: $ParametersFile" -ForegroundColor White
    
    # Execute deployment based on parameters
    if ($Validate) {
        Write-Host "`n===== VALIDATION ONLY =====" -ForegroundColor Yellow
        Write-Host "Testing deployment for errors..." -ForegroundColor Cyan
        
        $result = Test-AzSubscriptionDeployment `
            -Name $DeploymentName `
            -Location $Location `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $ParametersFile
        
        if ($result) {
            Write-Host "`nValidation successful!" -ForegroundColor Green
            Write-Host "No errors found in the template." -ForegroundColor Green
        }
    }
    elseif ($WhatIf) {
        Write-Host "`n===== WHAT-IF ANALYSIS =====" -ForegroundColor Yellow
        Write-Host "Analyzing deployment changes..." -ForegroundColor Cyan
        
        New-AzSubscriptionDeployment `
            -Name $DeploymentName `
            -Location $Location `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $ParametersFile `
            -WhatIf
    }
    else {
        Write-Host "`n===== DEPLOYMENT =====" -ForegroundColor Yellow
        Write-Host "Starting deployment..." -ForegroundColor Cyan
        
        $deployment = New-AzSubscriptionDeployment `
            -Name $DeploymentName `
            -Location $Location `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $ParametersFile `
            -Verbose `
            -ErrorAction Stop
        
        if ($deployment -and $deployment.ProvisioningState -eq "Succeeded") {
            Write-Host "`n========================================" -ForegroundColor Green
            Write-Host "  Deployment Completed Successfully!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            
            Write-Host "`nDeployment Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($deployment.DeploymentName)" -ForegroundColor White
            Write-Host "  State: $($deployment.ProvisioningState)" -ForegroundColor White
            Write-Host "  Timestamp: $($deployment.Timestamp)" -ForegroundColor White
            
            if ($deployment.Outputs) {
                Write-Host "`nOutputs:" -ForegroundColor Cyan
                $deployment.Outputs.GetEnumerator() | ForEach-Object {
                    Write-Host "  $($_.Key): $($_.Value.Value)" -ForegroundColor White
                }
            }
        }
        else {
            Write-Host "`n========================================" -ForegroundColor Red
            Write-Host "  Deployment Failed or Incomplete!" -ForegroundColor Red
            Write-Host "========================================" -ForegroundColor Red
            if ($deployment) {
                Write-Host "State: $($deployment.ProvisioningState)" -ForegroundColor Yellow
            }
            exit 1
        }
    }
    
    Write-Host "`nScript completed successfully." -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "  Deployment Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "`nError Details:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.InnerException) {
        Write-Host "`nInner Exception:" -ForegroundColor Red
        Write-Host $_.Exception.InnerException.Message -ForegroundColor Red
    }
    
    Write-Host "`nStack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    
    exit 1
}
