# Asana-Entra User Sync - TinyCo
param(
    [Parameter(Mandatory = $true)]
    [string]$AsanaToken,
    
    [Parameter(Mandatory = $true)]
    [string]$AsanaWorkspaceGid,
    
    [Parameter(Mandatory = $true)]
    [string]$AsanaAppDisplayName
)

$AsanaHeaders = @{
    'Authorization' = "Bearer $AsanaToken"
    'Accept' = 'application/json'
    'Content-Type' = 'application/json'
}

function Get-AsanaServicePrincipal {
    param([string]$DisplayName)
    
    $servicePrincipal = Get-MgServicePrincipal -Filter "displayName eq '$DisplayName'"
    if (-not $servicePrincipal) {
        throw "Service Principal not found: $DisplayName"
    }
    return $servicePrincipal.Id
}

function Get-AsanaAssignedUsers {
    param([string]$ServicePrincipalId)
    
    $assignments = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $ServicePrincipalId -All
    $assignedUsers = @()
    $assignedUserIds = @()
    
    foreach ($assignment in $assignments) {
        if ($assignment.PrincipalType -eq "Group") {
            $groupMembers = Get-MgGroupMember -GroupId $assignment.PrincipalId -All
            
            foreach ($member in $groupMembers) {
                if ($member.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.user' -and $member.Id -notin $assignedUserIds) {
                    $user = Get-MgUser -UserId $member.Id -Property Id,DisplayName,UserPrincipalName,AccountEnabled
                    if ($user.AccountEnabled -and $user.Id) {
                        $assignedUsers += $user
                        $assignedUserIds += $user.Id
                    }
                }
            }
        }
        elseif ($assignment.PrincipalType -eq "User" -and $assignment.PrincipalId -notin $assignedUserIds) {
            $user = Get-MgUser -UserId $assignment.PrincipalId -Property Id,DisplayName,UserPrincipalName,AccountEnabled
            if ($user.AccountEnabled -and $user.Id) {
                $assignedUsers += $user
                $assignedUserIds += $user.Id
            }
        }
    }
    return $assignedUsers
}

function Get-UserTeamGroups {
    param([string]$UserId)
    
    if ([string]::IsNullOrEmpty($UserId)) {
        Write-Warning "UserId is null or empty, skipping team group lookup"
        return @()
    }
    
    try {
        # Get group memberships and then get the full group details
        $memberOf = Get-MgUserMemberOf -UserId $UserId
        # Removed debug output for production
        
        $teamGroups = @()
        
        # Get full group details and filter for Team- groups
        foreach ($membership in $memberOf) {
            if ($membership.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group') {
                try {
                    # Get the full group details to access DisplayName
                    $group = Get-MgGroup -GroupId $membership.Id -Property Id,DisplayName,GroupTypes
                    
                    # Check if this is a Team- group
                    if ($group.DisplayName -like 'Team-*') {
                        $teamGroups += $group.DisplayName
                    }
                }
                catch {
                    Write-Warning "Could not retrieve group details for ID: $($membership.Id)"
                }
            }
        }
        
        return $teamGroups
    }
    catch {
        Write-Warning "Failed to get team groups for user $UserId`: $($_.Exception.Message)"
        return @()
    }
}

function New-AsanaTeam {
    param([string]$TeamName, [string]$Description)
    
    # Transform team name - remove "Team-" prefix for cleaner Asana team names
    $cleanTeamName = $TeamName -replace '^Team-', ''
    
    $body = @{
        data = @{
            name = $cleanTeamName
            description = $Description
            organization = $AsanaWorkspaceGid
        }
    } | ConvertTo-Json
    
    try {
        Write-Host "  Creating new team: '$cleanTeamName'" -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri "https://app.asana.com/api/1.0/teams" -Headers $AsanaHeaders -Method POST -Body $body -ContentType 'application/json'
        Write-Host "  Created team: '$cleanTeamName'" -ForegroundColor Green
        return $response.data
    }
    catch {
        Write-Host "  Failed to create team '$cleanTeamName': $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Send-AsanaInvite {
    param([string]$Email, [string]$DisplayName = "")
    
    $body = @{
        data = @{
            user = $Email
            name = $DisplayName
        }
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "https://app.asana.com/api/1.0/workspaces/$AsanaWorkspaceGid/addUser" -Headers $AsanaHeaders -Method POST -Body $body -ContentType 'application/json'
        Write-Host "Invited: $DisplayName ($Email)" -ForegroundColor Green
        return $response.data
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        # Better error response handling
        try {
            $errorResponse = $_.ErrorDetails.Message
            if ($errorResponse) {
                $errorObj = $errorResponse | ConvertFrom-Json
                if ($errorObj.errors -and $errorObj.errors[0].message) {
                    $specificError = $errorObj.errors[0].message
                } else {
                    $specificError = $errorResponse
                }
            }
        }
        catch {
            $specificError = $_.Exception.Message
        }
        
        if ($statusCode -eq 403) {
            Write-Host "User already exists: $DisplayName ($Email)" -ForegroundColor Yellow
        } elseif ($statusCode -eq 400) {
            Write-Host "Bad request for: $DisplayName ($Email) - $specificError" -ForegroundColor Yellow
        } else {
            Write-Host "Failed to invite $DisplayName ($Email): $specificError" -ForegroundColor Red
        }
        throw
    }
}

function Add-UserToTeam {
    param([string]$TeamGid, [string]$UserEmail)
    
    $users = Invoke-RestMethod -Uri "https://app.asana.com/api/1.0/users?workspace=$AsanaWorkspaceGid" -Headers $AsanaHeaders
    $user = $users.data | Where-Object { $_.email -eq $UserEmail }
    
    if ($user) {
        $body = @{ data = @{ user = $user.gid } } | ConvertTo-Json
        Invoke-RestMethod -Uri "https://app.asana.com/api/1.0/teams/$TeamGid/addUser" -Headers $AsanaHeaders -Method POST -Body $body
        Write-Host "  Added to team: $UserEmail" -ForegroundColor Green
    }
}

# Main execution
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "Application.Read.All"

Write-Host "Looking for Service Principal: '$AsanaAppDisplayName'" -ForegroundColor Cyan
$servicePrincipalId = Get-AsanaServicePrincipal -DisplayName $AsanaAppDisplayName
Write-Host "Found Service Principal ID: $servicePrincipalId" -ForegroundColor Green

Write-Host "Getting assigned users..." -ForegroundColor Cyan
$assignedUsers = Get-AsanaAssignedUsers -ServicePrincipalId $servicePrincipalId
Write-Host "Found $($assignedUsers.Count) assigned users" -ForegroundColor Green

Write-Host "Getting existing Asana teams..." -ForegroundColor Cyan
$existingTeams = (Invoke-RestMethod -Uri "https://app.asana.com/api/1.0/teams?workspace=$AsanaWorkspaceGid" -Headers $AsanaHeaders).data
Write-Host "Found $($existingTeams.Count) existing teams in Asana" -ForegroundColor Green

Write-Host "Processing users and their team memberships..." -ForegroundColor Cyan
$usersByTeam = @{}
foreach ($user in $assignedUsers) {
    if ($user.Id) {
        $teams = Get-UserTeamGroups -UserId $user.Id
        foreach ($team in $teams) {
            if (-not $usersByTeam[$team]) { $usersByTeam[$team] = @() }
            $usersByTeam[$team] += $user
        }
    } else {
        Write-Warning "User object missing Id property: $($user.DisplayName)"
    }
}
Write-Host "Total teams with users: $($usersByTeam.Keys.Count)" -ForegroundColor Green

# Process all users - invite them to Asana and add to appropriate teams
if ($assignedUsers.Count -eq 0) {
    Write-Host "No users found to process" -ForegroundColor Yellow
    Write-Host "Script completed - nothing to do!" -ForegroundColor Green
    Disconnect-MgGraph
    return
}

Write-Host "Processing $($assignedUsers.Count) users for Asana invitations..." -ForegroundColor Cyan
$invitedCount = 0
$skippedCount = 0

# If no team assignments found, just invite all users to workspace
if ($usersByTeam.Keys.Count -eq 0) {
    Write-Host "No team assignments found - inviting all users to workspace only" -ForegroundColor Yellow
    foreach ($user in $assignedUsers) {
        try {
            Send-AsanaInvite -Email $user.UserPrincipalName -DisplayName $user.DisplayName
            $invitedCount++
            Start-Sleep -Milliseconds 300  # Rate limiting
        }
        catch {
            $skippedCount++
        }
    }
} else {
    # Process users by team
    foreach ($teamName in $usersByTeam.Keys) {
        Write-Host "Processing team: $teamName" -ForegroundColor Magenta
        
        # Transform team name for Asana (remove Team- prefix)
        $cleanTeamName = $teamName -replace '^Team-', ''
        $asanaTeam = $existingTeams | Where-Object { $_.name -eq $cleanTeamName }
        
        if (-not $asanaTeam) {
            $asanaTeam = New-AsanaTeam -TeamName $teamName -Description "TinyCo $cleanTeamName"
        } else {
            Write-Host "  Using existing team: $cleanTeamName" -ForegroundColor Green
        }
        
        Write-Host "  Processing $($usersByTeam[$teamName].Count) users for team $teamName" -ForegroundColor Gray
        foreach ($user in $usersByTeam[$teamName]) {
            try {
                Send-AsanaInvite -Email $user.UserPrincipalName -DisplayName $user.DisplayName
                $invitedCount++
                Start-Sleep -Milliseconds 300  # Rate limiting
                Add-UserToTeam -TeamGid $asanaTeam.gid -UserEmail $user.UserPrincipalName
            }
            catch {
                $skippedCount++
            }
        }
    }
}

Write-Host "\nSummary:" -ForegroundColor Cyan
Write-Host "  Users processed: $($assignedUsers.Count)" -ForegroundColor Green
Write-Host "  Successfully invited: $invitedCount" -ForegroundColor Green
Write-Host "  Skipped (already existed): $skippedCount" -ForegroundColor Yellow

Write-Host "\nAsana-Entra User Sync completed successfully!" -ForegroundColor Green
Disconnect-MgGraph 