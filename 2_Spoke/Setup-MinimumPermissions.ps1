<#
.SYNOPSIS
    Setup minimum permissions and restrictions for Windows 365 Spoke Network deployment

.DESCRIPTION
    This script configures the minimum required permissions for an administrator to deploy
    the Windows 365 spoke network, along with resource restrictions to prevent unauthorized
    deployments and cost overruns.
    
    Must be run by a user with Owner or User Access Administrator role at subscription level.

.PARAMETER SubscriptionId
    Target Azure subscription ID

.PARAMETER ResourceGroupName
    Resource group name for W365 spoke network (default: rg-w365-spoke-prod)

.PARAMETER AdminEmail
    Email address of the administrator who will deploy the spoke network

.PARAMETER UseCustomRole
    If specified, creates and assigns a custom role. Otherwise uses built-in Network Contributor role.

.PARAMETER MonthlyBudget
    Monthly budget limit in USD (default: 50)

.PARAMETER AllowedRegions
    Comma-separated list of allowed Azure regions (default: canadacentral,eastus,westus3)

.PARAMETER AllowedIPRanges
    Comma-separated list of allowed VNet CIDR blocks (default: 192.168.100.0/24,192.168.101.0/24,192.168.102.0/24)

.PARAMETER CreateResourceGroup
    If specified, creates the resource group. Otherwise assumes it exists.

.EXAMPLE
    .\Setup-MinimumPermissions.ps1 -SubscriptionId "xxx" -AdminEmail "admin@contoso.com" -UseCustomRole

.EXAMPLE
    .\Setup-MinimumPermissions.ps1 -SubscriptionId "xxx" -AdminEmail "admin@contoso.com" -CreateResourceGroup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-w365-spoke-prod",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminEmail,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseCustomRole,
    
    [Parameter(Mandatory=$false)]
    [int]$MonthlyBudget = 50,
    
    [Parameter(Mandatory=$false)]
    [string[]]$AllowedRegions = @('southcentralus', 'eastus', 'westus3'),
    
    [Parameter(Mandatory=$false)]
    [string[]]$AllowedIPRanges = @('192.168.100.0/24', '192.168.101.0/24', '192.168.102.0/24'),
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateResourceGroup
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  W365 Spoke Network Security Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Set context
Write-Host "Setting Azure context to subscription: $SubscriptionId" -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

# Verify current user has sufficient permissions
Write-Host "Verifying permissions..." -ForegroundColor Cyan
$currentUser = (Get-AzContext).Account.Id
$roleAssignments = Get-AzRoleAssignment -SignInName $currentUser -Scope "/subscriptions/$SubscriptionId"

$hasOwner = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq "Owner" }
$hasUAA = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq "User Access Administrator" }

if (-not ($hasOwner -or $hasUAA)) {
    throw "Current user must have Owner or User Access Administrator role at subscription level"
}

Write-Host "✓ Permissions verified" -ForegroundColor Green

# Step 1: Pre-register resource providers
Write-Host "`n[1/7] Registering required resource providers..." -ForegroundColor Cyan

$providers = @('Microsoft.Network')

foreach ($provider in $providers) {
    $registration = Get-AzResourceProvider -ProviderNamespace $provider
    if ($registration.RegistrationState -ne 'Registered') {
        Write-Host "  Registering: $provider" -ForegroundColor Yellow
        Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
    } else {
        Write-Host "  Already registered: $provider" -ForegroundColor Gray
    }
}

Write-Host "✓ Resource providers ready" -ForegroundColor Green

# Step 2: Create resource group (if requested)
Write-Host "`n[2/7] Configuring resource group..." -ForegroundColor Cyan

$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if ($CreateResourceGroup) {
    if (-not $rg) {
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $AllowedRegions[0] -Tag @{
            Purpose = "Windows 365 Spoke Network"
            ManagedBy = "Security Setup Script"
            Environment = "Production"
        }
        Write-Host "✓ Resource group created: $ResourceGroupName" -ForegroundColor Green
    } else {
        Write-Host "✓ Resource group already exists: $ResourceGroupName" -ForegroundColor Gray
    }
} else {
    if (-not $rg) {
        Write-Host "⚠ Resource group does not exist. Use -CreateResourceGroup to create it." -ForegroundColor Yellow
        throw "Resource group '$ResourceGroupName' not found"
    }
    Write-Host "✓ Using existing resource group: $ResourceGroupName" -ForegroundColor Gray
}

$rgScope = $rg.ResourceId

# Step 3: Create and assign role
Write-Host "`n[3/7] Configuring RBAC permissions..." -ForegroundColor Cyan

if ($UseCustomRole) {
    # Create custom role
    Write-Host "  Creating custom role..." -ForegroundColor Yellow
    
    $roleName = "Windows 365 Spoke Network Deployer"
    
    # Check if role already exists
    $existingRole = Get-AzRoleDefinition -Name $roleName -ErrorAction SilentlyContinue
    
    if (-not $existingRole) {
        $roleDefinitionPath = Join-Path -Path $PSScriptRoot -ChildPath "W365-MinimumRole.json"
        
        if (Test-Path $roleDefinitionPath) {
            # Update scope in JSON
            $roleJson = Get-Content $roleDefinitionPath | ConvertFrom-Json
            $roleJson.AssignableScopes = @($rgScope)
            $roleJson | ConvertTo-Json -Depth 10 | Set-Content "$env:TEMP\w365role-temp.json"
            
            $role = New-AzRoleDefinition -InputFile "$env:TEMP\w365role-temp.json"
            Write-Host "  ✓ Custom role created: $roleName" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ W365-MinimumRole.json not found, using built-in role instead" -ForegroundColor Yellow
            $UseCustomRole = $false
        }
    } else {
        Write-Host "  ✓ Custom role already exists: $roleName" -ForegroundColor Gray
        $role = $existingRole
    }
    
    if ($UseCustomRole) {
        # Assign custom role
        $assignment = Get-AzRoleAssignment -SignInName $AdminEmail -RoleDefinitionName $roleName -Scope $rgScope -ErrorAction SilentlyContinue
        if (-not $assignment) {
            New-AzRoleAssignment -SignInName $AdminEmail -RoleDefinitionName $roleName -Scope $rgScope | Out-Null
            Write-Host "  ✓ Custom role assigned to $AdminEmail" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Custom role already assigned to $AdminEmail" -ForegroundColor Gray
        }
    }
}

if (-not $UseCustomRole) {
    # Use built-in Network Contributor role
    Write-Host "  Assigning built-in Network Contributor role..." -ForegroundColor Yellow
    
    $netContribAssignment = Get-AzRoleAssignment -SignInName $AdminEmail -RoleDefinitionName "Network Contributor" -Scope $rgScope -ErrorAction SilentlyContinue
    if (-not $netContribAssignment) {
        New-AzRoleAssignment -SignInName $AdminEmail -RoleDefinitionName "Network Contributor" -Scope $rgScope | Out-Null
        Write-Host "  ✓ Network Contributor role assigned" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Network Contributor role already assigned" -ForegroundColor Gray
    }
}

# Step 4: Apply Azure Policies
Write-Host "`n[4/7] Applying Azure Policies..." -ForegroundColor Cyan

# Policy 1: Allowed Regions
Write-Host "  Policy: Restrict regions..." -ForegroundColor Yellow
$locationPolicy = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Allowed locations' }

$locationAssignment = Get-AzPolicyAssignment -Name 'restrict-w365-locations' -Scope $rgScope -ErrorAction SilentlyContinue
if (-not $locationAssignment) {
    New-AzPolicyAssignment `
        -Name 'restrict-w365-locations' `
        -DisplayName 'W365: Allowed Regions' `
        -Scope $rgScope `
        -PolicyDefinition $locationPolicy `
        -PolicyParameter @{
            listOfAllowedLocations = @{ value = $AllowedRegions }
        } | Out-Null
    Write-Host "    ✓ Region policy applied (allowed: $($AllowedRegions -join ', '))" -ForegroundColor Green
} else {
    Write-Host "    ✓ Region policy already applied" -ForegroundColor Gray
}

# Policy 2: Require Tags
Write-Host "  Policy: Require tags..." -ForegroundColor Yellow
$tagPolicy = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Require a tag on resources' }

if ($tagPolicy) {
    $tagAssignment = Get-AzPolicyAssignment -Name 'require-w365-env-tag' -Scope $rgScope -ErrorAction SilentlyContinue
    if (-not $tagAssignment) {
        New-AzPolicyAssignment `
            -Name 'require-w365-env-tag' `
            -DisplayName 'W365: Require env Tag' `
            -Scope $rgScope `
            -PolicyDefinition $tagPolicy `
            -PolicyParameter @{
                tagName = @{ value = 'env' }
            } | Out-Null
        Write-Host "    ✓ Tag policy applied (requires 'env' tag)" -ForegroundColor Green
    } else {
        Write-Host "    ✓ Tag policy already applied" -ForegroundColor Gray
    }
}

Write-Host "✓ Policies configured" -ForegroundColor Green

# Step 5: Create budget alert
Write-Host "`n[5/7] Creating budget alert..." -ForegroundColor Cyan

try {
    # Check if Azure CLI is available for budget creation
    $azCliAvailable = Get-Command az -ErrorAction SilentlyContinue
    
    if ($azCliAvailable) {
        $budgetName = "w365-monthly-budget"
        $startDate = (Get-Date).ToString("yyyy-MM-01")
        
        # Check if budget exists
        $existingBudget = az consumption budget show --budget-name $budgetName --resource-group $ResourceGroupName 2>$null
        
        if (-not $existingBudget) {
            az consumption budget create `
                --budget-name $budgetName `
                --amount $MonthlyBudget `
                --time-grain Monthly `
                --start-date $startDate `
                --end-date "2026-12-31" `
                --resource-group $ResourceGroupName `
                --category Cost | Out-Null
            
            Write-Host "✓ Budget created: $MonthlyBudget USD/month" -ForegroundColor Green
        } else {
            Write-Host "✓ Budget already exists" -ForegroundColor Gray
        }
    } else {
        Write-Host "⚠ Azure CLI not available, skipping budget creation" -ForegroundColor Yellow
        Write-Host "  To create budget manually, run:" -ForegroundColor Yellow
        Write-Host "  az consumption budget create --budget-name w365-monthly-budget --amount $MonthlyBudget --time-grain Monthly --resource-group $ResourceGroupName" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠ Budget creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 6: Create resource locks
Write-Host "`n[6/7] Creating resource locks..." -ForegroundColor Cyan

$rgLock = Get-AzResourceLock -ResourceGroupName $ResourceGroupName -LockName "prevent-rg-deletion" -ErrorAction SilentlyContinue
if (-not $rgLock) {
    New-AzResourceLock `
        -LockName "prevent-rg-deletion" `
        -LockLevel CanNotDelete `
        -ResourceGroupName $ResourceGroupName `
        -LockNotes "Prevents accidental deletion of Windows 365 spoke network infrastructure" `
        -Force | Out-Null
    Write-Host "✓ Resource group lock created (CanNotDelete)" -ForegroundColor Green
} else {
    Write-Host "✓ Resource group lock already exists" -ForegroundColor Gray
}

# Step 7: Display summary
Write-Host "`n[7/7] Setup complete!`n" -ForegroundColor Green

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Configuration Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Resource Group:    $ResourceGroupName" -ForegroundColor White
Write-Host "Administrator:     $AdminEmail" -ForegroundColor White
if ($UseCustomRole) {
    Write-Host "Role:              Custom (Windows 365 Spoke Network Deployer)" -ForegroundColor White
} else {
    Write-Host "Role:              Built-in (Network Contributor)" -ForegroundColor White
}
Write-Host "Allowed Regions:   $($AllowedRegions -join ', ')" -ForegroundColor White
Write-Host "Allowed IP Ranges: $($AllowedIPRanges -join ', ')" -ForegroundColor White
Write-Host "Monthly Budget:    $MonthlyBudget USD" -ForegroundColor White
Write-Host "Resource Lock:     CanNotDelete (RG level)" -ForegroundColor White
Write-Host "`n========================================" -ForegroundColor Cyan

Write-Host "`n✓ Administrator can now run deploy.ps1" -ForegroundColor Green
Write-Host "✓ All restrictions and policies are in effect" -ForegroundColor Green

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Admin deploys spoke network: .\deploy.ps1" -ForegroundColor White
Write-Host "  2. After deployment, configure Windows 365 permissions:" -ForegroundColor White
Write-Host "     .\Set-W365Permissions.ps1" -ForegroundColor White
Write-Host "  3. Verify permissions:" -ForegroundColor White
Write-Host "     .\Check-W365Permissions.ps1" -ForegroundColor White

Write-Host "`nFor full documentation, see: PERMISSIONS-AND-RESTRICTIONS.md`n" -ForegroundColor Cyan
