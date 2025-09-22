# Create Team Groups for TinyCo Entra Tenant
# Requires Microsoft.Graph PowerShell module

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All"

# Define teams
$teams = @("ITOps", "SRE", "Security", "Backend", "Frontend", "Design", "Product", "PeopleOps", "Legal")

foreach ($team in $teams) {
    $groupName = "Team-$team"
    $dynamicRule = "user.department -eq `"$team`""
    
    Write-Host "Creating: $groupName"
    
    try {
        New-MgGroup -DisplayName $groupName `
                   -MailEnabled:$true `
                   -SecurityEnabled:$true `
                   -MailNickname $groupName.Replace("-", "").ToLower() `
                   -GroupTypes @("DynamicMembership") `
                   -MembershipRule $dynamicRule `
                   -MembershipRuleProcessingState "On" `
                   -Description "Dynamic group for $team team"
        
        Write-Host "Created: $groupName" -ForegroundColor Green
        
    } catch {
        Write-Host "Failed: $groupName - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Disconnect-MgGraph