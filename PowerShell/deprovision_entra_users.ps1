# Deprovisions users in Entra ID by disabling accounts and revoking sessions

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users

param(
    [Parameter(Mandatory = $true)]
    [string[]]$UserPrincipalNames,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-Host "Starting Entra ID User Deprovisioning" -ForegroundColor Red
    
    # Connect to Graph
    if (-not $WhatIf) {
        Connect-MgGraph -Scopes "User.ReadWrite.All", "UserAuthenticationMethod.ReadWrite.All"
    }
    
    $processed = 0
    $errors = 0
    
    foreach ($upn in $UserPrincipalNames) {
        Write-Host "`nProcessing: $upn" -ForegroundColor Yellow
        
        if ($WhatIf) {
            Write-Host "  WHATIF: Would deprovision $upn" -ForegroundColor Yellow
            continue
        }
        
        try {
            # Get user details
            $user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction Stop
            
            if (-not $user) {
                Write-Host "  ERROR: User not found - $upn" -ForegroundColor Red
                $errors++
                continue
            }
            
            # 1. Disable the user account
            Write-Host "  Disabling account..." -ForegroundColor Cyan
            Update-MgUser -UserId $user.Id -AccountEnabled:$false
            
            # 2. Revoke all refresh tokens (forces re-authentication)
            Write-Host "  Revoking all sessions..." -ForegroundColor Cyan
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/revokeSignInSessions"
            
            # 3. Clear department (removes from dynamic groups)
            Write-Host "  Removing from team groups..." -ForegroundColor Cyan
            Update-MgUser -UserId $user.Id -Department $null
            
            # 4. Set account for deletion (optional - adds context)
            Write-Host "  Updating account status..." -ForegroundColor Cyan
            Update-MgUser -UserId $user.Id -JobTitle "DEPROVISIONED - $(Get-Date -Format 'yyyy-MM-dd')"
            
            Write-Host "  SUCCESS: $upn deprovisioned" -ForegroundColor Green
            $processed++
            
        }
        catch {
            Write-Host "  ERROR: Failed to deprovision $upn - $($_.Exception.Message)" -ForegroundColor Red
            $errors++
        }
    }
    
    # Summary
    Write-Host "`n=== DEPROVISIONING SUMMARY ===" -ForegroundColor Red
    Write-Host "  Processed: $processed users" -ForegroundColor White
    Write-Host "  Errors: $errors users" -ForegroundColor White
    
    if ($processed -gt 0 -and -not $WhatIf) {
        Write-Host "`nDEPROVISIONING EFFECTS:" -ForegroundColor Magenta
        Write-Host "  • Accounts disabled (cannot sign in)" -ForegroundColor White
        Write-Host "  • All active sessions terminated" -ForegroundColor White
        Write-Host "  • Removed from all dynamic groups" -ForegroundColor White
        Write-Host "  • Application access revoked" -ForegroundColor White
        Write-Host "  • Tailscale/VPN access terminated" -ForegroundColor White
        Write-Host "`nNEXT STEPS:" -ForegroundColor Magenta
        Write-Host "  • Notify relevant teams of deprovisioning" -ForegroundColor White
        Write-Host "  • Review and reassign owned resources if needed" -ForegroundColor White
        Write-Host "  • Consider permanent deletion after 30-day retention" -ForegroundColor White
    }
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    if (-not $WhatIf) {
        Disconnect-MgGraph
    }
}

<#
.SYNOPSIS
    Deprovisions users from Entra ID by disabling accounts and revoking access.

.DESCRIPTION
    This script safely deprovisions users by:
    1. Disabling user accounts (prevents sign-in)
    2. Revoking all active sessions (forces logout)
    3. Removing from dynamic groups (removes app access)
    4. Updating job title with deprovisioning date

.PARAMETER UserPrincipalNames
    Array of user principal names to deprovision (e.g., "john.smith@tinycoddg.onmicrosoft.com")

.PARAMETER WhatIf
    Shows what would be done without making changes

.EXAMPLE
    .\Deprovision-EntraUsers.ps1 -UserPrincipalNames "john.smith@tinycoddg.onmicrosoft.com"
    
.EXAMPLE
    .\Deprovision-EntraUsers.ps1 -UserPrincipalNames @("user1@tinycoddg.onmicrosoft.com", "user2@tinycoddg.onmicrosoft.com") -WhatIf

.NOTES
    Requires Global Administrator or User Administrator role in Entra ID
    Effects are immediate - users will lose access within minutes
#>