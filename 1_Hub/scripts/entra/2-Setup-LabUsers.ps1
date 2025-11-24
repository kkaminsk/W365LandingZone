<#
.SYNOPSIS
  Creates lab user accounts required by the landing-zone doc and writes credentials to a tenant-named file.

.DESCRIPTION
  Creates or reuses these cloud-only Entra ID users:
    - Break Glass 1  (breakglass1@<domain>)
    - Break Glass 2  (breakglass2@<domain>)
    - Student Administrator (student.admin@<domain>) and adds to grp-w365-admin
    - Student Test         (student.test@<domain>)

  - Generates strong passwords and writes them to <tenantName><tenantId>.txt in the chosen output directory.
  - Optionally rotates passwords for existing accounts.
  - Optionally creates M365 groups `grp-w365-admin` and `grp-w365-ops` if missing.

  NOTE: Writing credentials to disk is for lab/education only. Handle files securely and delete when done.

.REQUIREMENTS
  - PowerShell 7+ recommended
  - Microsoft Graph modules: Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups
  - Permissions: ability to create users and groups (e.g., User Administrator / Groups Administrator)

.EXAMPLE
  ./Setup-LabUsers.ps1 -UseDeviceCode

.EXAMPLE
  ./Setup-LabUsers.ps1 -DomainName "contoso.onmicrosoft.com" -RotatePasswords -OutputDirectory .
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$DomainName,
  [switch]$RotatePasswords,
  [string]$BreakGlass1UpnPrefix = 'breakglass1',
  [string]$BreakGlass2UpnPrefix = 'breakglass2',
  [string]$StudentAdminUpnPrefix = 'student.admin',
  [string]$StudentTestUpnPrefix = 'student.test',
  [string]$StudentAdminGroupName = 'grp-w365-admin',
  [string]$StudentOpsGroupName   = 'grp-w365-ops',
  [string]$OutputDirectory = '.',
  [switch]$UseDeviceCode
)

function Ensure-Module {
  param([Parameter(Mandatory)][string]$Name)
  if (-not (Get-Module -ListAvailable -Name $Name)) {
    Write-Host "Module '$Name' not found. Installing for CurrentUser..." -ForegroundColor Yellow
    try { Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop } catch { throw $_ }
  }
  Import-Module $Name -ErrorAction Stop | Out-Null
}

# Load required modules
Ensure-Module -Name Microsoft.Graph.Authentication
Ensure-Module -Name Microsoft.Graph.Users
Ensure-Module -Name Microsoft.Graph.Groups

# Connect to Graph
$scopes = @('User.ReadWrite.All','Group.ReadWrite.All','Directory.ReadWrite.All')
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
if ($UseDeviceCode) { Connect-MgGraph -Scopes $scopes -UseDeviceCode | Out-Null } else { Connect-MgGraph -Scopes $scopes | Out-Null }
Select-MgProfile -Name 'v1.0' | Out-Null

# Fetch organization (tenant) details, including verified domains
$org = Get-MgOrganization -Property Id,DisplayName,VerifiedDomains | Select-Object -First 1
if (-not $org) { throw 'Unable to retrieve organization info from Graph.' }
$tenantId = $org.Id
$tenantName = $org.DisplayName

# Determine domain
if (-not $DomainName -or [string]::IsNullOrWhiteSpace($DomainName)) {
  $defaultDomain = $org.VerifiedDomains | Where-Object { $_.IsDefault -eq $true } | Select-Object -First 1
  if ($defaultDomain) { $DomainName = $defaultDomain.Name }
  if (-not $DomainName) {
    $initial = $org.VerifiedDomains | Where-Object { $_.IsInitial -eq $true } | Select-Object -First 1
    if ($initial) { $DomainName = $initial.Name }
  }
}
if (-not $DomainName) { throw 'Could not determine tenant domain. Specify -DomainName explicitly.' }

# Utilities
function New-MailNickname([string]$Name) {
  $nick = ($Name -replace '[^a-zA-Z0-9]','')
  if ([string]::IsNullOrWhiteSpace($nick)) { $nick = "usr$([System.Random]::new().Next(100000,999999))" }
  $nick.ToLowerInvariant()
}

function Get-OrCreate-Group {
  [CmdletBinding()] param(
    [Parameter(Mandatory)][string]$DisplayName,
    [string]$Description = 'Lab group created by Setup-LabUsers.ps1'
  )
  $existing = Get-MgGroup -Filter "displayName eq '$($DisplayName.Replace("'","''"))'" -All -ConsistencyLevel eventual -ErrorAction SilentlyContinue
  if ($existing) { return $existing | Select-Object -First 1 }
  if ($PSCmdlet.ShouldProcess($DisplayName, 'Create Entra security group')) {
    $mailNick = New-MailNickname $DisplayName
    return New-MgGroup -DisplayName $DisplayName -MailEnabled:$false -MailNickname $mailNick -SecurityEnabled:$true -GroupTypes @() -Description $Description
  }
}

function New-StrongPassword([int]$Length = 24) {
  $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'  # omit easy-confused chars
  $lower = 'abcdefghijkmnopqrstuvwxyz'
  $digits = '23456789'
  $symbols = '!@#$%^&*()-_=+[]{}.,:?'
  $all = ($upper + $lower + $digits + $symbols).ToCharArray()
  $pick = {
    param($chars)
    $bytes = New-Object byte[] 4
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $idx = [BitConverter]::ToUInt32($bytes,0) % $chars.Length
    return $chars[$idx]
  }
  $passwordChars = @()
  $passwordChars += & $pick ($upper.ToCharArray())
  $passwordChars += & $pick ($lower.ToCharArray())
  $passwordChars += & $pick ($digits.ToCharArray())
  $passwordChars += & $pick ($symbols.ToCharArray())
  for ($i = $passwordChars.Count; $i -lt $Length; $i++) { $passwordChars += & $pick $all }
  # shuffle
  for ($i = 0; $i -lt $passwordChars.Count; $i++) { $j = (& $pick (0..($passwordChars.Count-1))) ; $tmp = $passwordChars[$i]; $passwordChars[$i] = $passwordChars[$j]; $passwordChars[$j] = $tmp }
  -join $passwordChars
}

function Ensure-User {
  [CmdletBinding()] param(
    [Parameter(Mandatory)] [string]$DisplayName,
    [Parameter(Mandatory)] [string]$UserPrincipalName,
    [switch]$BreakGlass,
    [switch]$RotatePassword
  )
  $existing = Get-MgUser -Filter "userPrincipalName eq '$($UserPrincipalName.Replace("'","''"))'" -All -ConsistencyLevel eventual -ErrorAction SilentlyContinue | Select-Object -First 1
  $pwd = New-StrongPassword 28
  if (-not $existing) {
    if ($PSCmdlet.ShouldProcess($UserPrincipalName, 'Create user')) {
      $mailNick = New-MailNickname $DisplayName
      $params = @{ 
        AccountEnabled = $true
        DisplayName = $DisplayName
        MailNickname = $mailNick
        UserPrincipalName = $UserPrincipalName
        PasswordProfile = @{ Password = $pwd; ForceChangePasswordNextSignIn = $false }
      }
      $user = New-MgUser @params
      if ($BreakGlass) {
        Update-MgUser -UserId $user.Id -PasswordPolicies 'DisablePasswordExpiration' | Out-Null
      }
      return @{ Id = $user.Id; Upn = $UserPrincipalName; Password = $pwd; Created = $true }
    }
  } else {
    if ($RotatePassword) {
      if ($PSCmdlet.ShouldProcess($UserPrincipalName, 'Rotate password')) {
        Update-MgUser -UserId $existing.Id -PasswordProfile @{ Password = $pwd; ForceChangePasswordNextSignIn = $false } | Out-Null
        if ($BreakGlass) { Update-MgUser -UserId $existing.Id -PasswordPolicies 'DisablePasswordExpiration' | Out-Null }
        return @{ Id = $existing.Id; Upn = $UserPrincipalName; Password = $pwd; Created = $false; Rotated = $true }
      }
    }
    # Return without password if not rotated
    return @{ Id = $existing.Id; Upn = $UserPrincipalName; Password = $null; Created = $false }
  }
}

# Ensure groups for Student Admin flows
$grpAdmin = Get-OrCreate-Group -DisplayName $StudentAdminGroupName -Description 'Intune admin group for students (assign Intune role separately)'
$grpOps   = Get-OrCreate-Group -DisplayName $StudentOpsGroupName -Description 'Intune help desk operator group (assign role separately)'

# Create or reuse users
$break1Upn = "$BreakGlass1UpnPrefix@$DomainName"
$break2Upn = "$BreakGlass2UpnPrefix@$DomainName"
$studAdmUpn = "$StudentAdminUpnPrefix@$DomainName"
$studTstUpn = "$StudentTestUpnPrefix@$DomainName"

$u1 = Ensure-User -DisplayName 'Break Glass 1' -UserPrincipalName $break1Upn -BreakGlass -RotatePassword:$RotatePasswords
$u2 = Ensure-User -DisplayName 'Break Glass 2' -UserPrincipalName $break2Upn -BreakGlass -RotatePassword:$RotatePasswords
$u3 = Ensure-User -DisplayName 'Student Administrator' -UserPrincipalName $studAdmUpn -RotatePassword:$RotatePasswords
$u4 = Ensure-User -DisplayName 'Student Test' -UserPrincipalName $studTstUpn -RotatePassword:$RotatePasswords

# Add Student Admin to admin group
if ($u3.Id -and $grpAdmin.Id) {
  $already = Get-MgGroupMember -GroupId $grpAdmin.Id -All -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq $u3.Id }
  if (-not $already) {
    New-MgGroupMemberByRef -GroupId $grpAdmin.Id -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$($u3.Id)" | Out-Null
  }
}

# Prepare output file name <tenant name><tenant id>.txt (sanitized)
$tenantNameSanitized = ($tenantName -replace '[^a-zA-Z0-9]','')
if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory | Out-Null }
$outPath = Join-Path -Path $OutputDirectory -ChildPath ("{0}{1}.txt" -f $tenantNameSanitized, $tenantId.Replace('-',''))

# Build content
$lines = @()
$lines += "Generated: $(Get-Date -Format o)"
$lines += "Tenant Name: $tenantName"
$lines += "Tenant Id:   $tenantId"
$lines += "Domain:      $DomainName"
$lines += ""
$lines += "Accounts (store securely; for lab use only):"
foreach ($u in @($u1,$u2,$u3,$u4)) {
  $label = switch ($u.Upn) {
    { $_ -eq $break1Upn } { 'Break Glass 1' ; break }
    { $_ -eq $break2Upn } { 'Break Glass 2' ; break }
    { $_ -eq $studAdmUpn } { 'Student Administrator' ; break }
    { $_ -eq $studTstUpn } { 'Student Test' ; break }
    default { 'User' }
  }
  if ($u.Password) {
    $lines += "- $label: $($u.Upn) | Password: $($u.Password)"
  } else {
    $lines += "- $label: $($u.Upn) | Password: <unchanged>"
  }
}
$lines += ""
$lines += "Student Admin group: $StudentAdminGroupName (id: $($grpAdmin.Id))"
$lines += "Student Ops group:   $StudentOpsGroupName (id: $($grpOps.Id))"

Set-Content -LiteralPath $outPath -Value $lines -NoNewline:$false -Encoding UTF8
Write-Host "Credentials written to: $outPath" -ForegroundColor Green
