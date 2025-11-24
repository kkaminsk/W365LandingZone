# Quick Start: Deploy Windows 365 Spoke Network

## Prerequisites Check

```powershell
# RECOMMENDED: Install all required modules at once
cd ..\InstallStudentModules
.\InstallStudentModules.ps1

# Check Bicep
bicep --version

# If Bicep not installed:
winget install -e --id Microsoft.Bicep
```

## Login to Azure

```powershell
# Login
Connect-AzAccount

# Verify subscription
Get-AzContext
```

## Validate & Deploy

```powershell
# Navigate to W365 folder
cd W365

# Step 1: Validate for student 1 (always run first!)
.\deploy.ps1 -Validate -StudentNumber 1

# Step 2: Preview changes (optional)
.\deploy.ps1 -WhatIf -StudentNumber 1

# Step 3: Deploy for student 1
.\deploy.ps1 -StudentNumber 1

# For other students, change the StudentNumber (1-40)
# Student 5 example:
.\deploy.ps1 -StudentNumber 5
```

## Expected Output

```
✓ Deployment successful (Example for Student 1)
Resource Group: rg-w365-spoke-student1-prod
VNet: vnet-w365-spoke-student1-prod (192.168.1.0/24)
Cloud PC Subnet: 192.168.1.0/26
Management Subnet: 192.168.1.64/26
```

## Common Issues

**Permission Error?**
- Need Contributor or Network Contributor role
- Contact your Azure subscription admin

**Location Error?**
- Use `southcentralus` not `south-central-us`
- Azure locations don't use hyphens

**Need more help?**
- See [Deployps1-Readme.md](./Deployps1-Readme.md) for full documentation

## What's Next?

After deployment:
1. ✅ Configure Windows 365 provisioning policy
2. ✅ Deploy Cloud PCs to `snet-cloudpc` subnet
3. ✅ (Optional) Set up hub peering
4. ✅ Enable monitoring and diagnostics
