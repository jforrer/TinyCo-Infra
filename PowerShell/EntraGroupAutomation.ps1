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
        #check if group already exists
        $existingGroup = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction SilentlyContinue
        if ($existingGroup) {
            Write-Host "Group $groupName already exists. Skipping..." -ForegroundColor Yellow
            continue
        }
        # Create dynamic groups
        New-MgGroup -DisplayName $groupName `
            -MailEnabled:$false `
            -SecurityEnabled:$true `
            -MailNickname $groupName.Replace("-", "").ToLower() `
            -GroupTypes @("DynamicMembership") `
            -MembershipRule $dynamicRule `
            -MembershipRuleProcessingState "On" `
            -Description "Dynamic group for $team team"
        
        Write-Host "Created: $groupName" -ForegroundColor Green
        
    }
    catch {
        Write-Host "Failed: $groupName - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Disconnect-MgGraph