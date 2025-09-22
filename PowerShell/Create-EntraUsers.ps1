
# Creates users in entra from a .csv file with headers 'First name', 'Last name', 'Team'

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvFilePath = "employee_db.csv",
    
    [Parameter(Mandatory = $true)]
    [string]$Domain = "TinyCoDDG.onmicrosoft.com",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Generate secure temporary password that meets Entra ID complexity requirements
function New-TempPassword {
    # Entra ID requires: 8+ chars, 3 of 4 categories (upper, lower, number, special)
    # Generate 10 characters, mostly letters
    
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lowercase = "abcdefghijklmnopqrstuvwxyz" 
    $numbers = "0123456789"
    $specials = "!@#$%"
    
    # Start with one from each category to guarantee compliance
    $password = ""
    $password += $uppercase[(Get-Random -Maximum $uppercase.Length)]
    $password += $lowercase[(Get-Random -Maximum $lowercase.Length)]
    $password += $numbers[(Get-Random -Maximum $numbers.Length)]
    $password += $specials[(Get-Random -Maximum $specials.Length)]
    
    # Fill remaining 6 characters mostly with letters (4 letters, 2 more random)
    $letters = $uppercase + $lowercase
    for ($i = 4; $i -lt 8; $i++) {
        $password += $letters[(Get-Random -Maximum $letters.Length)]
    }
    
    # Add 2 more random characters from all categories
    $allChars = $uppercase + $lowercase + $numbers + $specials
    for ($i = 8; $i -lt 10; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }
    
    # Shuffle the password to randomize position of required characters
    $passwordArray = $password.ToCharArray()
    for ($i = $passwordArray.Length - 1; $i -gt 0; $i--) {
        $j = Get-Random -Maximum ($i + 1)
        $temp = $passwordArray[$i]
        $passwordArray[$i] = $passwordArray[$j]
        $passwordArray[$j] = $temp
    }
    
    return -join $passwordArray
}

try {
    Write-Host "Starting Entra ID User Import" -ForegroundColor Green
    
    # Connect to Graph
    if (-not $WhatIf) {
        Connect-MgGraph -Scopes "User.ReadWrite.All"
    }
    
    # Import employees
    $employees = Import-Csv -Path $CsvFilePath
    Write-Host "Processing $($employees.Count) employees..." -ForegroundColor Yellow
    
    $passwords = @()
    $created = 0
    $updated = 0
    $errors = 0
    
    foreach ($emp in $employees) {
        $firstName = $emp.'First name'.Trim()
        $lastName = $emp.'Last name'.Trim()
        $team = $emp.Team.Trim()
        $upn = "$($firstName.ToLower()).$($lastName.ToLower())@$Domain"
        
        Write-Host "Processing: $firstName $lastName ($team)" -ForegroundColor Cyan
        
        if ($WhatIf) {
            Write-Host "  WHATIF: Would create/update $upn" -ForegroundColor Yellow
            continue
        }
        
        try {
            # Check if user exists
            $existingUser = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
            
            if ($existingUser) {
                # Update department for dynamic groups
                Update-MgUser -UserId $existingUser.Id -Department $team
                Write-Host "  Updated: $upn" -ForegroundColor Green
                $updated++
            } else {
                # Create new user
                $tempPassword = New-TempPassword
                
                $userParams = @{
                    AccountEnabled = $true
                    DisplayName = "$firstName $lastName"
                    UserPrincipalName = $upn
                    MailNickname = "$($firstName.ToLower())$($lastName.ToLower())"
                    GivenName = $firstName
                    Surname = $lastName
                    Department = $team
                    UsageLocation = "US"
                    PasswordProfile = @{
                        ForceChangePasswordNextSignIn = $true
                        Password = $tempPassword
                    }
                }
                
                New-MgUser @userParams | Out-Null
                Write-Host "  Created: $upn" -ForegroundColor Green
                
                $passwords += @{
                    Name = "$firstName $lastName"
                    Email = $upn
                    TempPassword = $tempPassword
                    Team = $team
                }
                $created++
            }
        }
        catch {
            Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
            $errors++
        }
    }
    
    # Summary
    Write-Host "`nSummary:" -ForegroundColor Green
    Write-Host "  Created: $created users" -ForegroundColor White
    Write-Host "  Updated: $updated users" -ForegroundColor White
    Write-Host "  Errors: $errors users" -ForegroundColor White
    
    # Export passwords if any were created
    if ($passwords.Count -gt 0 -and -not $WhatIf) {
        $passwordFile = "temp_passwords_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $passwords | Export-Csv -Path $passwordFile -NoTypeInformation
        Write-Host "`nPasswords saved to: $passwordFile" -ForegroundColor Magenta
        Write-Host "Distribute securely and delete after use!" -ForegroundColor Red
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