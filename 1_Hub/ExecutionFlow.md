# Hub Landing Zone Deployment - Execution Flow

This document outlines the user experience and execution flow of the `deploy.ps1` script used to deploy the Hub Landing Zone.

## Overview

The deployment script (`deploy.ps1`) is an interactive PowerShell tool that orchestrates the deployment of Azure resources defined in Bicep templates. It handles authentication, context switching, and deployment execution with support for validation and what-if analysis.

## usage

### Basic Execution
Run the script from a PowerShell terminal:
```powershell
.\deploy.ps1
```

### Optional Parameters
| Parameter | Description |
|-----------|-------------|
| `-WhatIf` | Performs a dry-run to see what resources will be created or modified without making changes. |
| `-Validate` | Validates the template syntax and configuration without deploying. |
| `-Location` | Specifies the Azure region (Default: `westus3`). |
| `-TenantId` | specific Tenant ID to use (skips interactive selection). |
| `-SubscriptionId` | Specific Subscription ID to use (skips interactive selection). |

**Examples:**
```powershell
# Dry run
.\deploy.ps1 -WhatIf

# Specific target
.\deploy.ps1 -TenantId "GUID" -SubscriptionId "GUID"
```

## Execution Flow

### 1. Prerequisites Check
*   **Module Verification**: The script first checks if the `Az` PowerShell module is installed.
*   **Action**: If missing, it prompts the user to install it.

### 2. Authentication & Context Selection
The script ensures you are deploying to the correct environment through a series of checks:

#### Login Status
*   Checks if you are currently logged into Azure.
*   **Action**: If not logged in, triggers an interactive browser login prompt (`Connect-AzAccount`).

#### Tenant Selection
1.  **Single Tenant**: If your account has access to only one tenant, it is selected automatically.
2.  **Multiple Tenants**: If multiple tenants are detected:
    *   Displays a numbered list of available tenants.
    *   **User Action**: Enter the number corresponding to the desired tenant.
3.  **Explicit Parameter**: If `-TenantId` was provided, validation is performed to ensure access.

*Note: The script attempts to re-authenticate to the selected tenant to ensure proper permissions (handling MFA requirements).*

#### Subscription Selection
1.  **Single Subscription**: If the tenant has only one subscription, it is selected automatically.
2.  **Multiple Subscriptions**: If multiple subscriptions are detected:
    *   Displays a numbered list of available subscriptions.
    *   **User Action**: Enter the number corresponding to the desired subscription.
3.  **Explicit Parameter**: If `-SubscriptionId` was provided, validation is performed.

### 3. Deployment Preparation
*   **File Validation**: Verifies that `infra\envs\prod\main.bicep` and parameters file exist.
*   **Bicep Build**: Compiles the Bicep template to an ARM JSON template.
    *   Tries using Azure CLI (`az bicep build`).
    *   Falls back to native PowerShell methods if CLI fails.

### 4. Deployment Execution
Depending on the flags used, one of three actions occurs:

*   **Validation Mode (`-Validate`)**:
    *   Runs `Test-AzSubscriptionDeployment`.
    *   Outputs "Validation successful!" or lists errors.
    *   *No resources are created.*

*   **What-If Mode (`-WhatIf`)**:
    *   Runs a deployment impact analysis.
    *   Outputs a list of resource Create/Modify/Delete actions.
    *   *No resources are created.*

*   **Standard Deployment (Default)**:
    *   Initiates the Azure deployment (`New-AzSubscriptionDeployment`).
    *   Displays "Starting deployment...".
    *   Waits for completion.

### 5. Completion & Outputs
*   **Success**:
    *   Displays "Deployment Completed Successfully!".
    *   Lists deployment details (Name, State, Timestamp).
    *   Shows any **Outputs** defined in the Bicep template (e.g., Resource Group names, IDs).
*   **Failure**:
    *   Displays "Deployment Failed!".
    *   Shows error messages, inner exceptions, and stack traces for debugging.

## Troubleshooting

*   **MFA/Authentication Errors**: If you see errors related to "User interaction is required", run `Connect-AzAccount` manually for that specific tenant before running the script again.
*   **Permissions**: Ensure you have `Owner` or `Contributor` rights on the target subscription.
*   **Bicep Errors**: If the build fails, check the Bicep file syntax in VS Code.
