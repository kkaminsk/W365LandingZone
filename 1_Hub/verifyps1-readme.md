# verify.ps1 - Hub Infrastructure Verification Script

## Overview

The `verify.ps1` script is a comprehensive validation tool that verifies the successful deployment of the Azure Hub infrastructure. It checks all deployed resources, validates their configuration, and generates detailed reports for troubleshooting and documentation purposes.

## Purpose

This script helps you:
- **Confirm Deployment Success**: Verify that all Hub resources were created correctly
- **Validate Configuration**: Check resource properties match expected values
- **Troubleshoot Issues**: Identify missing or misconfigured resources
- **Generate Documentation**: Create timestamped logs of infrastructure state
- **Audit Compliance**: Ensure infrastructure matches deployment specifications

## Prerequisites

### Required Software
- **PowerShell**: Version 5.1 or higher
- **Azure PowerShell Module**: Az module installed
  ```powershell
  Install-Module -Name Az -Repository PSGallery -Force -AllowClobber
  ```

### Required Permissions
- **Reader** role on the subscription or resource groups
- Ability to read Azure resource properties
- Access to the following resource providers:
  - Microsoft.Resources
  - Microsoft.Network
  - Microsoft.OperationalInsights
  - Microsoft.Insights

### Azure Context
- Must be logged into Azure: `Connect-AzAccount`
- Correct subscription must be selected: `Set-AzContext -Subscription "W365Lab"`

## Usage

### Basic Usage

Navigate to the Hub folder and run the script:

```powershell
cd Hub
.\verify.ps1
```

### Silent Execution (Log File Only)

Redirect console output if you only want the log file:

```powershell
.\verify.ps1 | Out-Null
```

### View Specific Sections

Use PowerShell filtering to view specific verification steps:

```powershell
# View only resource group verification
.\verify.ps1 | Select-String "Resource Groups"

# View first 20 lines (summary)
.\verify.ps1 | Select-Object -First 20

# View last 10 lines (summary)
.\verify.ps1 | Select-Object -Last 10
```

### Save Additional Copy of Output

```powershell
# Save both to log file and custom location
.\verify.ps1 | Tee-Object -FilePath "C:\temp\custom-verification.txt"
```

## Output

### Console Output

The script displays real-time progress to the console with color-coded status:
- **Cyan Headers**: Section titles (e.g., "=== Resource Groups ===")
- **Green Success**: Resources found and validated (e.g., "✓ Resource Group: rg-hub-net")
- **Yellow Warnings**: Optional resources not found (e.g., "⚠ Azure Firewall: Not deployed")
- **Red Errors**: Required resources missing (critical issues)
- **White Info**: Resource details and properties

### Log File

**Location**: `%USERPROFILE%\Documents\Verify-Hub-YYYY-MM-DD-HH-MM.log`

**Example Path**: 
```
C:\Users\KevinKaminski\OneDrive - Big Hat Group Inc\Documents\Verify-Hub-2025-10-03-12-16.log
```

**File Size**: Typically 15-20 KB

**Contents**:
- Timestamped execution record
- Complete resource inventory
- Detailed configuration properties
- Subnet details with address prefixes
- NSG rules and security configurations
- DNS zone configurations
- Diagnostic settings
- Summary statistics

### Finding Log Files

List all verification logs:

```powershell
Get-ChildItem "$([Environment]::GetFolderPath('MyDocuments'))\Verify-Hub-*.log"
```

View the most recent log:

```powershell
Get-ChildItem "$([Environment]::GetFolderPath('MyDocuments'))\Verify-Hub-*.log" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 | 
    Get-Content
```

## Verification Steps

The script performs 7 comprehensive verification steps:

### 1. Subscription Context
- **Verifies**: Current Azure subscription
- **Checks**: Subscription name and ID
- **Output**: Confirms you're connected to the correct subscription

### 2. Resource Groups
- **Verifies**: Both Hub resource groups exist
  - `rg-hub-net` - Networking resources
  - `rg-hub-ops` - Operational resources
- **Checks**: Resource group location, provisioning state
- **Expected**: 2 resource groups in canadacentral

### 3. Hub Virtual Network
- **Verifies**: Core VNet configuration
- **Checks**: 
  - VNet name: `vnet-hub`
  - Address space: `10.10.0.0/20`
  - Subnets: 3 (mgmt, priv-endpoints, AzureFirewallSubnet)
  - Subnet sizes and address prefixes
- **Expected**: 1 VNet with 3 properly configured subnets

### 4. Network Security Groups
- **Verifies**: NSG deployment and configuration
- **Checks**:
  - NSG names: `nsg-mgmt`, `nsg-priv-endpoints`
  - Security rules count
  - Rule configurations (if verbose)
  - Subnet associations
- **Expected**: 2 NSGs with security rules

### 5. Azure Firewall (Optional)
- **Verifies**: Firewall deployment if enabled
- **Checks**:
  - Firewall name and SKU
  - Public IP assignment
  - Firewall policy (if applicable)
- **Expected**: Either deployed firewall or warning that it's disabled

### 6. Private DNS Zones
- **Verifies**: DNS zone creation and VNet links
- **Checks**:
  - Zone names: `privatelink.blob.core.windows.net`, `privatelink.file.core.windows.net`
  - VNet link configurations
  - Auto-registration settings
- **Expected**: 2 DNS zones with VNet links

### 7. Operational Resources
- **Verifies**: Monitoring and operational tools
- **Checks**:
  - Log Analytics Workspace: `log-ops-hub`
  - Workspace SKU and retention
  - Diagnostic settings on subscription
- **Expected**: 1 Log Analytics workspace in rg-hub-ops

## Expected Results

### Successful Deployment

When all resources are deployed correctly, you should see:

```
===========================================
VERIFICATION SUMMARY
===========================================
Subscription: W365Lab
Timestamp: 2025-10-03 12:16:58

Resource Groups:         ✓ 2/2 found
Virtual Networks:        ✓ 1 found (3 subnets)
Network Security Groups: ✓ 2 found
Azure Firewall:          ⚠ Not deployed (optional)
Private DNS Zones:       ✓ 2 found
Operational Resources:   ✓ 1 found

Status: Hub infrastructure verified successfully
Log File: C:\Users\...\Documents\Verify-Hub-2025-10-03-12-16.log
===========================================
```

### Minimal Deployment (No Firewall)

If deployed without Azure Firewall (default configuration):
- All checks pass except Firewall
- Warning displayed: "⚠ Azure Firewall: Not deployed (optional)"
- Status: Still considered successful

### Missing Resources

If critical resources are missing:
- Red error messages indicate which resources are not found
- Summary shows incomplete counts (e.g., "Resource Groups: ✗ 1/2 found")
- Status: "Hub infrastructure verification completed with errors"
- Review deployment logs and re-run `deploy.ps1`

## Troubleshooting

### "Not logged into Azure"

**Error**: Script exits with authentication error

**Solution**:
```powershell
Connect-AzAccount
Set-AzContext -Subscription "W365Lab"
```

### "Resource group not found"

**Cause**: Deployment failed or incomplete

**Solution**:
1. Check deployment status: `Get-AzSubscriptionDeployment -Name "hub-deploy-*"`
2. Re-run deployment: `.\deploy.ps1`
3. Review deployment errors in the log

### "Cannot find VNet"

**Cause**: Networking resources not deployed

**Solution**:
1. Verify resource group exists: `Get-AzResourceGroup -Name "rg-hub-net"`
2. Check for failed deployments
3. Review `parameters.prod.json` for configuration errors
4. Re-deploy infrastructure

### "Log file not created"

**Cause**: Permissions issue or OneDrive sync problems

**Solution**:
```powershell
# Check Documents folder exists
Test-Path ([Environment]::GetFolderPath("MyDocuments"))

# Manually specify log location
$logFile = "C:\Temp\verify-hub.log"
.\verify.ps1 | Tee-Object -FilePath $logFile
```

### "Az module not found"

**Solution**:
```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force -AllowClobber

# Import module
Import-Module Az
```

## Advanced Usage

### Automated Verification

Integrate into CI/CD pipeline:

```powershell
# Run verification and check exit code
.\verify.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Hub verification failed"
    exit 1
}
```

### Custom Verification Checks

Modify the script to add environment-specific checks:

```powershell
# Add after existing verification steps
Write-Host "`n=== Custom Checks ===" -ForegroundColor Cyan

# Example: Check for specific tags
$rg = Get-AzResourceGroup -Name "rg-hub-net"
if ($rg.Tags["Environment"] -eq "Production") {
    Write-Host "✓ Environment tag validated" -ForegroundColor Green
}
```

### Export Results to JSON

Create machine-readable output:

```powershell
# Add at end of script
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ResourceGroups = 2
    VirtualNetworks = 1
    NSGs = 2
    DNSZones = 2
    Status = "Success"
}

$results | ConvertTo-Json | Out-File "verification-results.json"
```

## Best Practices

1. **Run After Every Deployment**: Verify infrastructure immediately after running `deploy.ps1`
2. **Keep Logs**: Archive verification logs for compliance and audit trails
3. **Compare Over Time**: Use logs to track infrastructure changes
4. **Automate**: Integrate into deployment pipelines for continuous validation
5. **Document**: Keep verification results with deployment documentation
6. **Version Control**: Do not commit log files to Git (already in .gitignore)

## File Structure

```
Hub/
├── verify.ps1                    # This verification script
├── verifyps1-readme.md          # This documentation
├── deploy.ps1                    # Deployment script
├── Deployps1-Readme.md          # Deployment documentation
└── infra/
    └── envs/
        └── prod/
            ├── main.bicep        # Infrastructure template
            └── parameters.prod.json  # Configuration
```

## Related Documentation

- **deploy.ps1**: See `Deployps1-Readme.md` for deployment instructions
- **Infrastructure**: See `infra/envs/prod/main.bicep` for resource definitions
- **Architecture**: See `Landing Zone (Hub-Only, Minimal).md` for design overview
- **Quick Start**: See `QUICKSTART.md` for rapid deployment guide

## Support

### Common Questions

**Q: How often should I run verification?**  
A: After every deployment, after configuration changes, and periodically for drift detection.

**Q: Can I run this in Azure Cloud Shell?**  
A: Yes, but log files will be saved to Cloud Shell storage, not local Documents folder.

**Q: Does this script modify any resources?**  
A: No, it only reads resource properties. It's safe to run anytime.

**Q: What if I deployed with custom resource names?**  
A: Edit the script to match your naming convention (lines 30-40).

### Getting Help

1. Review the log file for detailed error messages
2. Check Azure Portal for resource status
3. Review deployment logs: `Get-AzSubscriptionDeployment`
4. Consult `Deployps1-Readme.md` for deployment troubleshooting
5. Verify Azure PowerShell module is up to date: `Update-Module Az`

## Changelog

### Version 1.1 (Current)
- Changed log file location to user's Documents folder
- Improved cross-platform compatibility with `[Environment]::GetFolderPath()`
- Enhanced summary output with emoji indicators

### Version 1.0
- Initial release
- 7-step verification process
- Console and file logging
- Resource group, networking, DNS, and operational checks

## License

This script is part of the TechmentorOrlando-2025-Windows365 project.

---

**Last Updated**: October 3, 2025  
**Script Version**: 1.1  
**Author**: Generated for W365Lab Hub Infrastructure
