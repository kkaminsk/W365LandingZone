<#
.SYNOPSIS
  Creates Entra ID security groups for Azure RBAC and assigns roles at RG scope.

.DESCRIPTION
  - Creates (or reuses) groups:
      * grp-platform-network-admins  (Owner on rg-hub-net)
      * grp-platform-ops             (Contributor on rg-hub-ops)
      * (optional) auditors group    (Reader on one or both RGs)
  - Optionally seeds group membership from UPN lists.
  - Assigns Azure RBAC at resource group scope using Az PowerShell.

.REQUIREMENTS
  - PowerShell 7+ recommended
  - Modules: Az.Accounts, Az.Resources, Microsoft.Graph (Authentication, Groups, Users)
  - Permissions:
      * Azure: Owner or (Contributor + User Access Administrator) on the subscription
      * Entra: Ability to create security groups (e.g., Groups Administrator) and read users
  - Admin consent may be required for Microsoft Graph scopes (Group.ReadWrite.All)

.EXAMPLE
  ./Setup-RbacGroups.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" `
    -RgNetName "rg-hub-net" -RgOpsName "rg-hub-ops" `
    -NetworkAdminsGroupName "grp-platform-network-admins" `
    -OpsGroupName "grp-platform-ops" `
    -NetworkAdminMembersUpns @('alice@contoso.com') `
    -OpsMembersUpns @('bob@contoso.com')

.EXAMPLE
  ./Setup-RbacGroups.ps1 -SubscriptionId $env:AZ_SUBSCRIPTION_ID -RgNetName rg-hub-net -RgOpsName rg-hub-ops -AuditorsGroupName "grp-auditors" -AssignReaderToBothRGs

.NOTES
  This script is idempotent: it reuses existing groups and role assignments when present.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory=$true)]
  [string]$SubscriptionId,

  [Parameter(Mandatory=$true)]
  [string]$RgNetName = 'rg-hub-net',

  [Parameter(Mandatory=$true)]
  [string]$RgOpsName = 'rg-hub-ops',

  [string]$NetworkAdminsGroupName = 'grp-platform-network-admins',
  [string]$OpsGroupName          = 'grp-platform-ops',
  [string]$AuditorsGroupName,

  [string[]]$NetworkAdminMembersUpns = @(),
  [string[]]$OpsMembersUpns = @(),
  [string[]]$AuditorMembersUpns = @(),

  [switch]$AssignReaderToBothRGs,
  [switch]$UseDeviceCode,
  [switch]$DryRun
)

# --- Helper: Ensure module present ---
function Ensure-Module {
  param(
    [Parameter(Mandatory)] [string]$Name
  )
  if (-not (Get-Module -ListAvailable -Name $Name)) {
    Write-Host "Module '$Name' not found. Installing for CurrentUser..." -ForegroundColor Yellow
    try {
      Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    } catch {
      throw "Failed to install module '$Name'. Please install it manually. Error: $($_.Exception.Message)"
    }
  }
  Import-Module $Name -ErrorAction Stop | Out-Null
}

# --- Prereq modules ---
Ensure-Module -Name Az.Accounts
Ensure-Module -Name Az.Resources
Ensure-Module -Name Microsoft.Graph.Authentication
Ensure-Module -Name Microsoft.Graph.Groups
Ensure-Module -Name Microsoft.Graph.Users

# --- Connect to Azure ---
if (-not (Get-AzContext)) {
  Write-Host "Connecting to Azure..." -ForegroundColor Cyan
  Connect-AzAccount | Out-Null
}
Set-AzContext -Subscription $SubscriptionId | Out-Null
$ctx = Get-AzContext
Write-Host "Azure context: $($ctx.Name) / Sub: $($ctx.Subscription.Id)" -ForegroundColor Green

# --- Connect to Microsoft Graph ---
$scopes = @('Group.ReadWrite.All','User.Read.All','Directory.ReadWrite.All')
Write-Host "Connecting to Microsoft Graph with scopes: $($scopes -join ', ')" -ForegroundColor Cyan
if ($UseDeviceCode) {
  Connect-MgGraph -Scopes $scopes -UseDeviceCode | Out-Null
} else {
  Connect-MgGraph -Scopes $scopes | Out-Null
}
Select-MgProfile -Name "v1.0" | Out-Null

# --- Helpers ---
function New-MailNickname {
  param([string]$Name)
  $nick = ($Name -replace '[^a-zA-Z0-9]','')
  if ([string]::IsNullOrWhiteSpace($nick)) { $nick = "grp$([System.Random]::new().Next(100000,999999))" }
  return $nick.ToLowerInvariant()
}

function Get-OrCreate-Group {
  [CmdletBinding()] param(
    [Parameter(Mandatory)][string]$DisplayName,
    [string]$Description = "Azure RBAC group created by Setup-RbacGroups.ps1"
  )
  $existing = Get-MgGroup -Filter "displayName eq '$($DisplayName.Replace("'","''"))'" -All -ConsistencyLevel eventual -ErrorAction SilentlyContinue
  if ($existing) {
    return $existing | Select-Object -First 1
  }
  if ($PSCmdlet.ShouldProcess($DisplayName, 'Create Entra security group')) {
    $mailNick = New-MailNickname -Name $DisplayName
    return New-MgGroup -DisplayName $DisplayName -Description $Description -MailEnabled:$false -MailNickname $mailNick -SecurityEnabled:$true -GroupTypes @()
  }
}

function Add-MembersToGroup {
  [CmdletBinding()] param(
    [Parameter(Mandatory)] [string]$GroupId,
    [string[]]$MemberUpns = @()
  )
  foreach ($upn in ($MemberUpns | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
    $user = Get-MgUser -Filter "userPrincipalName eq '$($upn.Replace("'","''"))'" -All -ConsistencyLevel eventual -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $user) {
      Write-Warning "User not found: $upn"
      continue
    }
    $already = Get-MgGroupMember -GroupId $GroupId -All -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq $user.Id }
    if ($already) { continue }
    if ($PSCmdlet.ShouldProcess($upn, "Add to group $GroupId")) {
      New-MgGroupMemberByRef -GroupId $GroupId -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)" | Out-Null
    }
  }
}

function Ensure-RoleAssignment {
  [CmdletBinding()] param(
    [Parameter(Mandatory)][string]$ObjectId,
    [Parameter(Mandatory)][string]$RoleName,
    [Parameter(Mandatory)][string]$Scope
  )
  $exists = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -ErrorAction SilentlyContinue | Where-Object { $_.RoleDefinitionName -eq $RoleName }
  if ($exists) { return $true }
  if ($PSCmdlet.ShouldProcess("$RoleName @ $Scope", "Assign to ObjectId $ObjectId")) {
    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleName -Scope $Scope | Out-Null
    return $true
  }
}

# --- Create or reuse groups ---
$netGroup = Get-OrCreate-Group -DisplayName $NetworkAdminsGroupName -Description 'Owner on rg-hub-net'
$opsGroup = Get-OrCreate-Group -DisplayName $OpsGroupName -Description 'Contributor on rg-hub-ops'
$audGroup = $null
if ($AuditorsGroupName) {
  $audGroup = Get-OrCreate-Group -DisplayName $AuditorsGroupName -Description 'Reader on hub RGs'
}

# --- Seed membership (optional) ---
Add-MembersToGroup -GroupId $netGroup.Id -MemberUpns $NetworkAdminMembersUpns
Add-MembersToGroup -GroupId $opsGroup.Id -MemberUpns $OpsMembersUpns
if ($audGroup) { Add-MembersToGroup -GroupId $audGroup.Id -MemberUpns $AuditorMembersUpns }

# --- Build scopes ---
$rgNetScope = "/subscriptions/$SubscriptionId/resourceGroups/$RgNetName"
$rgOpsScope = "/subscriptions/$SubscriptionId/resourceGroups/$RgOpsName"

# --- Assign Azure RBAC ---
Ensure-RoleAssignment -ObjectId $netGroup.Id -RoleName 'Owner' -Scope $rgNetScope | Out-Null
Ensure-RoleAssignment -ObjectId $opsGroup.Id -RoleName 'Contributor' -Scope $rgOpsScope | Out-Null
if ($audGroup) {
  Ensure-RoleAssignment -ObjectId $audGroup.Id -RoleName 'Reader' -Scope $rgNetScope | Out-Null
  if ($AssignReaderToBothRGs) {
    Ensure-RoleAssignment -ObjectId $audGroup.Id -RoleName 'Reader' -Scope $rgOpsScope | Out-Null
  }
}

# --- Output summary ---
$summary = [pscustomobject]@{
  SubscriptionId = $SubscriptionId
  RgNetName      = $RgNetName
  RgOpsName      = $RgOpsName
  NetworkAdmins  = @{ Name = $NetworkAdminsGroupName; ObjectId = $netGroup.Id; Scope = $rgNetScope; Role = 'Owner' }
  OpsGroup       = @{ Name = $OpsGroupName; ObjectId = $opsGroup.Id; Scope = $rgOpsScope; Role = 'Contributor' }
  Auditors       = if ($audGroup) { @{ Name = $AuditorsGroupName; ObjectId = $audGroup.Id; Scopes = @($rgNetScope, ($(if ($AssignReaderToBothRGs) { $rgOpsScope }))) | Where-Object { $_ }; Role = 'Reader' } } else { $null }
}

$summary | ConvertTo-Json -Depth 6 | Write-Output
