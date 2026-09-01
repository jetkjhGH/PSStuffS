<#
.SYNOPSIS
    Interactively creates one or more educationClass Microsoft Teams via the Microsoft Graph API.

.DESCRIPTION
    Prompts for the creation method, the team owner, a naming convention, and how many
    teams to create, then provisions the teams.

    Before creating anything, generated names are checked against existing groups in the
    tenant and against each other, and any conflicts are reported for confirmation.

    Two creation methods are supported:

    Non-Activated - Creates a Microsoft 365 Unified group carrying the education
                    extension attribute (ObjectType = Section), then teamifies it with
                    the educationClass template. The class appears in Teams in a
                    non-activated (pending activation) state, matching how School Data
                    Sync provisions classes.

                    This runs in two phases: all groups are created first, the batch is
                    given time to replicate, and only then is each group teamified with
                    retries. The Teams templates backend returns 404 until it can see a
                    newly created group, so teamifying immediately after creation fails
                    intermittently.

    Activated     - Creates the team directly from the educationClass template. The
                    class is immediately active for the owner and members.

    The script assumes an existing Microsoft Graph session; it validates the connection
    and required scopes but does not call Connect-MgGraph.

.EXAMPLE
    .\New-EducationClassTeams.ps1

    Runs the fully interactive experience.

.EXAMPLE
    .\New-EducationClassTeams.ps1 -WhatIf

    Walks the prompts and previews every team that would be created without writing to
    the tenant.

.NOTES
    Required delegated scopes:
        Group.ReadWrite.All, Team.Create, TeamMember.ReadWrite.All, User.Read.All

    Requires the Microsoft.Graph PowerShell SDK (Microsoft.Graph.Authentication,
    Microsoft.Graph.Groups, Microsoft.Graph.Teams, Microsoft.Graph.Users).
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuration

# Scopes the script needs. Validated against the active session, never requested.
$script:RequiredScopes = @(
    'Group.ReadWrite.All'
    'Team.Create'
    'TeamMember.ReadWrite.All'
    'User.Read.All'
)

$script:GraphBaseUri = 'https://graph.microsoft.com/v1.0'

# Education extension attribute that marks a group as an unactivated class section.
$script:EducationObjectTypeAttribute = 'extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType'

# SharePoint app role grants and provisioning switches applied to SDS-style class groups.
# Kept here so they can be reviewed and adjusted without touching the creation logic.
$script:ClassResourceBehaviorOptions = @(
    'appRoleForSite:22d27567-b3f0-4dc2-9ec2-46ed368ba538:fullcontrol'
    'appRoleForSite:c9a559d2-7aab-4f13-a6ed-e7e9c52aec87:fullcontrol'
    'appRoleForSite:13291f5a-59ac-4c59-b0fa-d1632e8f3292:fullcontrol'
    'appRoleForSite:2d4d3d8e-2be3-4bef-9f87-7875a61c29de:fullcontrol'
    'appRoleForSite:8f348934-64be-4bb2-bc16-c54c96789f43:fullcontrol'
    'InstantOnDisabled'
    'FileNotificationsDisabled'
    'ProvisionSiteOnDemand'
    'WelcomeEmailDisabled'
    'ConnectorsDisabled'
    'SubscribeNewGroupMembers'
)

$script:ClassCreationOptions = @('ExchangeProvisioningFlags:4556')

# Minimum time to let a batch of new groups replicate before teamifying any of them.
# The Teams templates backend 404s until it can see the group, so this is a floor, not a
# guarantee; Convert-GroupToClassTeam still retries on top of it.
$script:GroupSettleSeconds = 30

# Naming templates offered to the user. Add entries here to expose new conventions.
# {Index} is appended automatically when a pattern omits it and more than one team is
# requested, so every generated name stays unique.
$script:NamingTemplates = @(
    [pscustomobject]@{
        Name    = 'Subject - Period - School Year'
        Pattern = '{Subject} - Period {Period} - {SchoolYear}'
    }
    [pscustomobject]@{
        Name    = 'Teacher - Subject - School Year'
        Pattern = '{Teacher} - {Subject} - {SchoolYear}'
    }
    [pscustomobject]@{
        Name    = 'School Year - Subject - Section'
        Pattern = '{SchoolYear} {Subject} Section {Index}'
    }
    [pscustomobject]@{
        Name    = 'Subject only'
        Pattern = '{Subject}'
    }
)

# Tokens a pattern may contain. Each is prompted for once and reused across the batch,
# except {Index}, which is substituted per team.
$script:NamingTokens = @{
    '{Subject}'    = 'Subject or course name'
    '{Period}'     = 'Class period'
    '{SchoolYear}' = 'School year (e.g. 2025-2026)'
    '{Teacher}'    = 'Teacher name'
}

$script:IndexToken = '{Index}'

#endregion Configuration

#region Prompt helpers

function Read-Choice {
    <#
    .SYNOPSIS
        Displays a numbered menu and returns the selected item.
    .OUTPUTS
        The selected element of -Options.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string] $Title,

        [Parameter(Mandatory)]
        [object[]] $Options,

        # Optional script block that converts an option into its menu label.
        [scriptblock] $LabelSelector = { param($Item) [string] $Item }
    )

    Write-Host ''
    Write-Host $Title -ForegroundColor Cyan

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $label = & $LabelSelector $Options[$i]
        Write-Host ("  [{0}] {1}" -f ($i + 1), $label)
    }

    while ($true) {
        $answer = Read-Host -Prompt ("Select 1-{0}" -f $Options.Count)
        $parsed = 0

        if ([int]::TryParse($answer, [ref] $parsed) -and $parsed -ge 1 -and $parsed -le $Options.Count) {
            return $Options[$parsed - 1]
        }

        Write-Warning ("Enter a number between 1 and {0}." -f $Options.Count)
    }
}

function Read-RequiredValue {
    <#
    .SYNOPSIS
        Prompts until the user supplies a non-empty value that passes optional validation.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Prompt,

        # Returns $true when the trimmed input is acceptable.
        [scriptblock] $Validator = { $true },

        [string] $ValidationMessage = 'That value is not valid. Try again.'
    )

    while ($true) {
        $value = (Read-Host -Prompt $Prompt)

        if ($null -ne $value) {
            $value = $value.Trim()
        }

        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Warning 'A value is required.'
            continue
        }

        if (& $Validator $value) {
            return $value
        }

        Write-Warning $ValidationMessage
    }
}

function Read-Confirmation {
    <#
    .SYNOPSIS
        Prompts for a yes/no answer.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Prompt
    )

    while ($true) {
        $answer = (Read-Host -Prompt ("{0} [y/n]" -f $Prompt))

        switch -Regex ($answer) {
            '^(y|yes)$' { return $true }
            '^(n|no)$'  { return $false }
            default     { Write-Warning "Enter 'y' or 'n'." }
        }
    }
}

#endregion Prompt helpers

#region Graph connection

function Test-GraphConnection {
    <#
    .SYNOPSIS
        Verifies an active Microsoft Graph session that holds the required scopes.
    .DESCRIPTION
        Throws with actionable guidance when no session exists or scopes are missing.
        App-only sessions are accepted without scope inspection because their permissions
        are surfaced as roles rather than delegated scopes.
    #>
    [CmdletBinding()]
    param()

    $context = $null

    try {
        $context = Get-MgContext
    }
    catch {
        throw "The Microsoft Graph PowerShell SDK is not available. Install it with: Install-Module Microsoft.Graph -Scope CurrentUser"
    }

    if (-not $context) {
        throw ("No Microsoft Graph session was found. Connect first, for example:{0}    Connect-MgGraph -Scopes {1}" -f [Environment]::NewLine, ($script:RequiredScopes -join ','))
    }

    Write-Host ("Connected to tenant {0} as {1}." -f $context.TenantId, $context.Account) -ForegroundColor Green

    if ($context.AuthType -eq 'AppOnly') {
        Write-Verbose 'App-only session detected; skipping delegated scope validation.'
        return
    }

    $granted = @()
    if ($context.Scopes) {
        $granted = $context.Scopes
    }

    $missing = $script:RequiredScopes | Where-Object { $_ -notin $granted }

    if ($missing) {
        throw ("The current session is missing required scopes: {0}{1}Reconnect with:{1}    Connect-MgGraph -Scopes {2}" -f ($missing -join ', '), [Environment]::NewLine, ($script:RequiredScopes -join ','))
    }
}

#endregion Graph connection

#region Owner resolution

function Resolve-TeamOwner {
    <#
    .SYNOPSIS
        Prompts for a team owner as a UPN/email or object ID and resolves it in Graph.
    .OUTPUTS
        PSCustomObject with Id, UserPrincipalName, and DisplayName.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    Write-Host ''
    Write-Host 'Team owner' -ForegroundColor Cyan
    Write-Host '  Enter a user principal name / email address, or an object ID (GUID).'

    while ($true) {
        $ownerInput = Read-RequiredValue -Prompt 'Owner'

        $lookupId = $ownerInput
        $emptyGuid = [guid]::Empty

        if ([guid]::TryParse($ownerInput, [ref] $emptyGuid)) {
            Write-Verbose "Owner input parsed as an object ID."
        }
        else {
            Write-Verbose "Owner input treated as a user principal name."
        }

        try {
            $user = Get-MgUser -UserId $lookupId -Property 'id,displayName,userPrincipalName' -ErrorAction Stop

            $owner = [pscustomobject]@{
                Id                = $user.Id
                UserPrincipalName = $user.UserPrincipalName
                DisplayName       = $user.DisplayName
            }

            Write-Host ("  Resolved to {0} ({1})" -f $owner.DisplayName, $owner.UserPrincipalName) -ForegroundColor Green
            return $owner
        }
        catch {
            Write-Warning ("Could not resolve '{0}': {1}" -f $ownerInput, $_.Exception.Message)
        }
    }
}

#endregion Owner resolution

#region Naming

function Get-NamingPattern {
    <#
    .SYNOPSIS
        Prompts the user to pick a predefined naming template or supply a custom pattern.
    .OUTPUTS
        The chosen pattern string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $customOption = [pscustomobject]@{
        Name    = 'Custom pattern'
        Pattern = $null
    }

    $options = @($script:NamingTemplates) + $customOption

    $choice = Read-Choice -Title 'Naming convention' -Options $options -LabelSelector {
        param($Item)
        if ($Item.Pattern) { "{0}   ->   {1}" -f $Item.Name, $Item.Pattern } else { $Item.Name }
    }

    if ($choice.Pattern) {
        return $choice.Pattern
    }

    $knownTokens = @($script:NamingTokens.Keys) + $script:IndexToken
    Write-Host ("  Available tokens: {0}" -f ($knownTokens -join ', '))

    return Read-RequiredValue -Prompt 'Custom pattern' -ValidationMessage 'The pattern must contain at least one supported token.' -Validator {
        param($Value)
        $knownTokens | Where-Object { $Value -like ("*{0}*" -f $_) } | Select-Object -First 1
    }
}

function Get-TokenValues {
    <#
    .SYNOPSIS
        Prompts once for each naming token present in the pattern.
    .OUTPUTS
        Hashtable of token -> user supplied value.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $Pattern
    )

    $values = @{}

    # Prompt in the order the tokens appear in the pattern so the questions read naturally.
    $ordered = $script:NamingTokens.Keys |
        Where-Object { $Pattern -like ("*{0}*" -f $_) } |
        Sort-Object { $Pattern.IndexOf($_) }

    foreach ($token in $ordered) {
        $values[$token] = Read-RequiredValue -Prompt ("  {0}" -f $script:NamingTokens[$token])
    }

    return $values
}

function New-TeamNameList {
    <#
    .SYNOPSIS
        Expands a naming pattern into the requested number of unique display names.
    .DESCRIPTION
        Token values are substituted for the whole batch; {Index} is substituted per team.
        When more than one team is requested and the pattern omits {Index}, an index is
        appended so names remain unique.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $Pattern,

        [Parameter(Mandatory)]
        [hashtable] $TokenValues,

        [Parameter(Mandatory)]
        [ValidateRange(1, 500)]
        [int] $Count,

        [ValidateRange(1, 500)]
        [int] $StartIndex = 1
    )

    $effectivePattern = $Pattern

    if ($Count -gt 1 -and $effectivePattern -notlike ("*{0}*" -f $script:IndexToken)) {
        $effectivePattern = "{0} {1}" -f $effectivePattern, $script:IndexToken
    }

    foreach ($token in $TokenValues.Keys) {
        $effectivePattern = $effectivePattern.Replace($token, $TokenValues[$token])
    }

    $names = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $Count; $i++) {
        $index = $StartIndex + $i
        $names.Add($effectivePattern.Replace($script:IndexToken, [string] $index).Trim())
    }

    return $names.ToArray()
}

function New-MailNickname {
    <#
    .SYNOPSIS
        Derives a unique, Graph-safe mail nickname from a display name.
    .DESCRIPTION
        Strips characters that Exchange rejects, truncates to a safe length, and appends a
        numeric suffix when the alias is already taken in the tenant or earlier in the batch.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $DisplayName,

        # Aliases already generated during this run but not yet visible in Graph.
        [string[]] $ReservedNicknames = @()
    )

    $maxLength = 60

    $base = [regex]::Replace($DisplayName, '[^a-zA-Z0-9]', '')

    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = 'class'
    }

    if ($base.Length -gt $maxLength) {
        $base = $base.Substring(0, $maxLength)
    }

    $candidate = $base
    $suffix = 1

    while (Test-MailNicknameInUse -MailNickname $candidate -ReservedNicknames $ReservedNicknames) {
        $suffixText = [string] $suffix
        $trimLength = [Math]::Min($base.Length, $maxLength - $suffixText.Length)
        $candidate = "{0}{1}" -f $base.Substring(0, $trimLength), $suffixText
        $suffix++

        if ($suffix -gt 999) {
            throw ("Unable to generate a unique mail nickname from '{0}'." -f $DisplayName)
        }
    }

    return $candidate
}

function Get-GroupIdsByDisplayName {
    <#
    .SYNOPSIS
        Returns the ids of every group whose display name matches exactly.
    .DESCRIPTION
        Display names are not unique in Entra ID, so this can legitimately return
        multiple ids. Used both to warn about conflicts before creation and to
        distinguish a newly created team from pre-existing ones afterwards.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $DisplayName
    )

    $escaped = $DisplayName.Replace("'", "''")

    try {
        $groups = Get-MgGroup -Filter ("displayName eq '{0}'" -f $escaped) -All -ErrorAction Stop
        return @($groups | ForEach-Object { $_.Id })
    }
    catch {
        Write-Verbose ("Display name lookup failed for '{0}': {1}" -f $DisplayName, $_.Exception.Message)
        return @()
    }
}

function Test-NameConflict {
    <#
    .SYNOPSIS
        Checks a set of proposed display names against existing groups in the tenant.
    .DESCRIPTION
        Entra ID permits duplicate group display names, so a conflict is a warning rather
        than a hard error. Surfacing it before creation avoids accidentally creating a
        second team indistinguishable from an existing one.
    .OUTPUTS
        One object per proposed name with Conflict and ExistingIds populated.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string[]] $Names
    )

    $results = New-Object System.Collections.Generic.List[pscustomobject]

    foreach ($name in $Names) {
        $existingIds = @(Get-GroupIdsByDisplayName -DisplayName $name)

        $results.Add([pscustomobject]@{
            DisplayName = $name
            Conflict    = ($existingIds.Count -gt 0)
            ExistingIds = $existingIds
        })
    }

    return $results.ToArray()
}

function Test-MailNicknameInUse {
    <#
    .SYNOPSIS
        Reports whether a mail nickname is already reserved locally or present in the tenant.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $MailNickname,

        [string[]] $ReservedNicknames = @()
    )

    if ($ReservedNicknames -contains $MailNickname) {
        return $true
    }

    try {
        $existing = Get-MgGroup -Filter ("mailNickname eq '{0}'" -f $MailNickname) -ConsistencyLevel eventual -CountVariable groupCount -Top 1 -ErrorAction Stop
        return [bool] $existing
    }
    catch {
        # A failed uniqueness probe should not block creation; Graph enforces uniqueness too.
        Write-Verbose ("Mail nickname uniqueness check failed for '{0}': {1}" -f $MailNickname, $_.Exception.Message)
        return $false
    }
}

#endregion Naming

#region Team creation

function New-ClassGroup {
    <#
    .SYNOPSIS
        Creates the Microsoft 365 Unified group that backs a non-activated class team.
    .DESCRIPTION
        Phase one of the non-activated flow. Only creates the group; teamification is a
        separate step so an entire batch of groups can settle before any are teamified.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [string] $Description,

        [Parameter(Mandatory)]
        [string] $MailNickname,

        [Parameter(Mandatory)]
        [string] $OwnerId
    )

    $ownerBinding = "{0}/users/{1}" -f $script:GraphBaseUri, $OwnerId

    # Built as a hashtable rather than a here-string so values are escaped correctly.
    $groupBody = [ordered]@{
        displayName                        = $DisplayName
        description                        = $Description
        groupTypes                         = @('Unified')
        mailEnabled                        = $true
        mailNickname                       = $MailNickname
        securityEnabled                    = $false
        visibility                         = 'HiddenMembership'
        creationOptions                    = $script:ClassCreationOptions
        resourceBehaviorOptions            = $script:ClassResourceBehaviorOptions
        'members@odata.bind'               = @($ownerBinding)
        'owners@odata.bind'                = @($ownerBinding)
        $script:EducationObjectTypeAttribute = 'Section'
    }

    if (-not $PSCmdlet.ShouldProcess($DisplayName, 'Create class group')) {
        return $null
    }

    $json = $groupBody | ConvertTo-Json -Depth 5
    $group = Invoke-MgGraphRequest -Uri ("{0}/groups" -f $script:GraphBaseUri) -Method POST -Body $json -ContentType 'application/json'

    $groupId = $group.id

    if (-not $groupId) {
        throw 'Group creation did not return an id.'
    }

    Write-Verbose ("Created group {0} for '{1}'." -f $groupId, $DisplayName)

    return $groupId
}

function Convert-GroupToClassTeam {
    <#
    .SYNOPSIS
        Teamifies an existing group with the educationClass template, with retries.
    .DESCRIPTION
        Phase two of the non-activated flow.

        The Teams templates backend replicates a newly created group asynchronously, and
        until that finishes it returns 404 / "Failed to execute
        GetGroupMembersMezzoCountAsync". A successful Get-MgGroup does not mean the Teams
        service can see the group yet, so this retries on transient failures rather than
        treating the first error as fatal.

        Non-transient errors (for example authorization failures) are rethrown immediately
        so genuine problems are not masked by pointless retrying.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $GroupId,

        [Parameter(Mandatory)]
        [string] $DisplayName,

        [int] $MaxAttempts = 8,

        [int] $InitialDelaySeconds = 10,

        [int] $MaxDelaySeconds = 60
    )

    if (-not $PSCmdlet.ShouldProcess($DisplayName, 'Teamify class group')) {
        return $true
    }

    $teamParams = @{
        'template@odata.bind' = "{0}/teamsTemplates('educationClass')" -f $script:GraphBaseUri
        'group@odata.bind'    = "{0}/groups('{1}')" -f $script:GraphBaseUri, $GroupId
    }

    $delay = $InitialDelaySeconds

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            # SilentlyContinue keeps the SDK from writing the raw 404 to the console on
            # attempts that are expected to fail while replication catches up.
            $null = New-MgTeam -BodyParameter $teamParams -ErrorAction Stop

            if ($attempt -gt 1) {
                Write-Host ("  Teamified on attempt {0}." -f $attempt) -ForegroundColor Green
            }

            return $true
        }
        catch {
            $message = $_.Exception.Message

            if (Test-TeamAlreadyExistsError -Message $message) {
                Write-Verbose ("Group {0} is already teamified." -f $GroupId)
                return $true
            }

            if (-not (Test-TransientTeamifyError -Message $message)) {
                throw
            }

            if ($attempt -eq $MaxAttempts) {
                throw ("Teamification of '{0}' (group {1}) failed after {2} attempts. Last error: {3}" -f $DisplayName, $GroupId, $MaxAttempts, $message)
            }

            Write-Host ("  Not ready yet (attempt {0}/{1}); retrying in {2}s..." -f $attempt, $MaxAttempts, $delay) -ForegroundColor DarkYellow
            Start-Sleep -Seconds $delay

            # Back off gradually; replication delay varies with tenant load.
            $delay = [Math]::Min($delay * 2, $MaxDelaySeconds)
        }
    }

    return $false
}

function Test-TransientTeamifyError {
    <#
    .SYNOPSIS
        Determines whether a teamification failure is worth retrying.
    .DESCRIPTION
        Matches the signatures the Teams templates backend returns while a group is still
        replicating, plus generic throttling and gateway errors.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Message
    )

    $transientSignatures = @(
        'GetGroupMembersMezzoCountAsync'
        'CreateTeamFromGroupWithTemplateRequest'
        'NotFound'
        '404'
        'Failed to execute Templates backend request'
        'TooManyRequests'
        '429'
        'ServiceUnavailable'
        '503'
        'BadGateway'
        '502'
        'GatewayTimeout'
        '504'
        'timed out'
    )

    foreach ($signature in $transientSignatures) {
        if ($Message -like ("*{0}*" -f $signature)) {
            return $true
        }
    }

    return $false
}

function Test-TeamAlreadyExistsError {
    <#
    .SYNOPSIS
        Detects the case where a retry succeeded server-side but the response was lost.
    .DESCRIPTION
        Prevents a redundant retry from being reported as a failure when the group was in
        fact already teamified by an earlier attempt.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Message
    )

    $existsSignatures = @(
        'already has a team'
        'already exists'
        'Conflict'
        'TeamAlreadyExists'
    )

    foreach ($signature in $existsSignatures) {
        if ($Message -like ("*{0}*" -f $signature)) {
            return $true
        }
    }

    return $false
}

function New-ActivatedClassTeam {
    <#
    .SYNOPSIS
        Creates an activated educationClass team directly from the template.
    .DESCRIPTION
        Creates the team in a single call, then adds the requested user as a team owner.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [string] $Description,

        [Parameter(Mandatory)]
        [string] $OwnerId,

        # Group ids that already used this display name before creation started.
        [string[]] $PreExistingIds = @()
    )

    if (-not $PSCmdlet.ShouldProcess($DisplayName, 'Create activated class team')) {
        return [pscustomobject]@{
            GroupId = $null
            TeamId  = $null
        }
    }

    $teamParams = @{
        'template@odata.bind' = "{0}/teamsTemplates('educationClass')" -f $script:GraphBaseUri
        displayName           = $DisplayName
        description           = $Description
    }

    $team = New-MgTeam -BodyParameter $teamParams

    $teamId = $null
    if ($team -and $team.Id) {
        $teamId = $team.Id
    }

    if (-not $teamId) {
        # New-MgTeam returns the team asynchronously; fall back to a lookup by display name.
        $teamId = Resolve-TeamIdByDisplayName -DisplayName $DisplayName -ExcludeIds $PreExistingIds
    }

    if (-not $teamId) {
        throw ("Team '{0}' was submitted for creation but its id could not be determined." -f $DisplayName)
    }

    Add-TeamOwner -TeamId $teamId -OwnerId $OwnerId

    return [pscustomobject]@{
        GroupId = $teamId
        TeamId  = $teamId
    }
}

function Resolve-TeamIdByDisplayName {
    <#
    .SYNOPSIS
        Looks up a newly created team by display name, retrying while it provisions.
    .DESCRIPTION
        Display names are not unique, so -ExcludeIds is used to ignore groups that already
        carried this name before creation. Without that, a pre-existing team with the same
        name could be mistaken for the new one and modified by the caller.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $DisplayName,

        # Group ids observed with this display name before creation started.
        [string[]] $ExcludeIds = @(),

        [int] $MaxAttempts = 12,

        [int] $DelaySeconds = 5
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $candidates = @(Get-GroupIdsByDisplayName -DisplayName $DisplayName | Where-Object { $_ -notin $ExcludeIds })

        if ($candidates.Count -eq 1) {
            return $candidates[0]
        }

        if ($candidates.Count -gt 1) {
            throw ("Multiple new groups named '{0}' were found; cannot determine which one was just created." -f $DisplayName)
        }

        Write-Verbose ("Team '{0}' not yet visible (attempt {1}/{2})." -f $DisplayName, $attempt, $MaxAttempts)
        Start-Sleep -Seconds $DelaySeconds
    }

    return $null
}

function Add-TeamOwner {
    <#
    .SYNOPSIS
        Adds a user as an owner of an existing team.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string] $TeamId,

        [Parameter(Mandatory)]
        [string] $OwnerId
    )

    if (-not $PSCmdlet.ShouldProcess($TeamId, 'Add team owner')) {
        return
    }

    $memberParams = @{
        '@odata.type'     = '#microsoft.graph.aadUserConversationMember'
        roles             = @('owner')
        'user@odata.bind' = "{0}/users('{1}')" -f $script:GraphBaseUri, $OwnerId
    }

    $null = New-MgTeamMember -TeamId $TeamId -BodyParameter $memberParams
}

#endregion Team creation

#region Main

function Invoke-ClassTeamCreation {
    <#
    .SYNOPSIS
        Runs the interactive workflow end to end.
    .OUTPUTS
        One result object per requested team.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param()

    Write-Host ''
    Write-Host '=== Create educationClass Teams ===' -ForegroundColor Cyan

    Test-GraphConnection

    $creationTypes = @(
        [pscustomobject]@{
            Key         = 'NonActivated'
            Label       = 'Non-Activated  - group with education extension, then teamify (SDS style)'
        }
        [pscustomobject]@{
            Key         = 'Activated'
            Label       = 'Activated      - create the team directly from the educationClass template'
        }
    )

    $creationType = Read-Choice -Title 'Creation method' -Options $creationTypes -LabelSelector { param($Item) $Item.Label }

    $owner = Resolve-TeamOwner

    $pattern = Get-NamingPattern
    $tokenValues = Get-TokenValues -Pattern $pattern

    $countText = Read-RequiredValue -Prompt 'How many teams should be created?' -ValidationMessage 'Enter a whole number between 1 and 500.' -Validator {
        param($Value)
        $parsed = 0
        [int]::TryParse($Value, [ref] $parsed) -and $parsed -ge 1 -and $parsed -le 500
    }
    $count = [int] $countText

    $startIndexText = '1'
    if ($count -gt 1) {
        $startIndexText = Read-RequiredValue -Prompt 'Start numbering at' -ValidationMessage 'Enter a whole number between 1 and 500.' -Validator {
            param($Value)
            $parsed = 0
            [int]::TryParse($Value, [ref] $parsed) -and $parsed -ge 1 -and $parsed -le 500
        }
    }
    $startIndex = [int] $startIndexText

    $description = Read-RequiredValue -Prompt 'Class description'

    $names = New-TeamNameList -Pattern $pattern -TokenValues $tokenValues -Count $count -StartIndex $startIndex

    # A pattern with no distinguishing token can yield repeats within the batch itself,
    # which a tenant-side check would not catch since none exist yet.
    $duplicates = @($names | Group-Object | Where-Object { $_.Count -gt 1 })

    if ($duplicates.Count -gt 0) {
        Write-Host ''
        Write-Warning 'The chosen naming convention produces duplicate names within this batch:'
        foreach ($duplicate in $duplicates) {
            Write-Host ("  - {0} (x{1})" -f $duplicate.Name, $duplicate.Count) -ForegroundColor Yellow
        }
        Write-Host 'Re-run and choose a pattern that includes {Index}, or vary the token values.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host 'Checking the tenant for existing teams with these names...' -ForegroundColor Cyan
    $nameChecks = Test-NameConflict -Names $names

    # Indexed by name so the creation loop can exclude pre-existing groups when it later
    # has to identify the team it just created.
    $existingIdsByName = @{}
    foreach ($check in $nameChecks) {
        $existingIdsByName[$check.DisplayName] = $check.ExistingIds
    }

    Write-Host ''
    Write-Host 'The following teams will be created:' -ForegroundColor Cyan
    foreach ($check in $nameChecks) {
        if ($check.Conflict) {
            Write-Host ("  - {0}   [!] {1} existing team(s) already use this name" -f $check.DisplayName, $check.ExistingIds.Count) -ForegroundColor Yellow
        }
        else {
            Write-Host ("  - {0}" -f $check.DisplayName)
        }
    }
    Write-Host ("Method: {0}   Owner: {1}" -f $creationType.Key, $owner.UserPrincipalName)

    $conflicts = @($nameChecks | Where-Object { $_.Conflict })

    if ($conflicts.Count -gt 0) {
        Write-Host ''
        Write-Warning ("{0} of {1} name(s) already exist in the tenant. Entra ID allows duplicate group display names, so creating these will produce teams that are hard to tell apart." -f $conflicts.Count, $nameChecks.Count)

        if (-not (Read-Confirmation -Prompt 'Continue anyway?')) {
            Write-Host 'Cancelled. No teams were created.' -ForegroundColor Yellow
            return
        }
    }

    if (-not (Read-Confirmation -Prompt 'Proceed?')) {
        Write-Host 'Cancelled. No teams were created.' -ForegroundColor Yellow
        return
    }

    $results = New-Object System.Collections.Generic.List[pscustomobject]
    $reservedNicknames = New-Object System.Collections.Generic.List[string]
    $position = 0

    foreach ($name in $names) {
        $position++

        $preExistingIds = @($existingIdsByName[$name])

        $result = [pscustomobject]@{
            DisplayName  = $name
            Method       = $creationType.Key
            MailNickname = $null
            GroupId      = $null
            TeamId       = $null
            NameConflict = ($preExistingIds.Count -gt 0)
            Status       = 'Failed'
            Error        = $null
        }

        if ($creationType.Key -eq 'NonActivated') {
            # Phase one only creates the group; teamification happens after the whole
            # batch has had time to replicate.
            Write-Host ''
            Write-Host ("[{0}/{1}] Creating group: {2}" -f $position, $names.Count, $name) -ForegroundColor Cyan

            try {
                $mailNickname = New-MailNickname -DisplayName $name -ReservedNicknames $reservedNicknames.ToArray()
                $reservedNicknames.Add($mailNickname)
                $result.MailNickname = $mailNickname

                $groupId = New-ClassGroup -DisplayName $name -Description $description -MailNickname $mailNickname -OwnerId $owner.Id

                $result.GroupId = $groupId

                if ($WhatIfPreference) {
                    $result.Status = 'WhatIf'
                }
                else {
                    $result.Status = 'GroupCreated'
                    Write-Host ("  Group id: {0}" -f $groupId) -ForegroundColor Green
                }
            }
            catch {
                $result.Error = $_.Exception.Message
                Write-Warning ("  Failed: {0}" -f $_.Exception.Message)
            }
        }
        else {
            Write-Host ''
            Write-Host ("[{0}/{1}] {2}" -f $position, $names.Count, $name) -ForegroundColor Cyan

            try {
                $created = New-ActivatedClassTeam -DisplayName $name -Description $description -OwnerId $owner.Id -PreExistingIds $preExistingIds

                $result.GroupId = $created.GroupId
                $result.TeamId = $created.TeamId

                if ($WhatIfPreference) {
                    $result.Status = 'WhatIf'
                }
                else {
                    $result.Status = 'Created'
                    Write-Host ("  Created. Team id: {0}" -f $created.TeamId) -ForegroundColor Green
                }
            }
            catch {
                $result.Error = $_.Exception.Message
                Write-Warning ("  Failed: {0}" -f $_.Exception.Message)
            }
        }

        $results.Add($result)
    }

    if ($creationType.Key -eq 'NonActivated') {
        Invoke-TeamificationPhase -Results $results
    }

    Write-ResultSummary -Results $results

    return $results.ToArray()
}

function Invoke-TeamificationPhase {
    <#
    .SYNOPSIS
        Teamifies every successfully created group after letting the batch settle.
    .DESCRIPTION
        Phase two of the non-activated flow. Waits a fixed settle period so the Teams
        templates backend has a chance to replicate the new groups, then teamifies each one
        with its own retry loop. Updates each result object in place.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[pscustomobject]] $Results
    )

    $pending = @($Results | Where-Object { $_.Status -eq 'GroupCreated' -and $_.GroupId })

    if ($pending.Count -eq 0) {
        return
    }

    Write-Host ''
    Write-Host ("Waiting {0}s for {1} group(s) to replicate before teamifying..." -f $script:GroupSettleSeconds, $pending.Count) -ForegroundColor Cyan
    Start-Sleep -Seconds $script:GroupSettleSeconds

    $position = 0

    foreach ($result in $pending) {
        $position++
        Write-Host ''
        Write-Host ("[{0}/{1}] Teamifying: {2}" -f $position, $pending.Count, $result.DisplayName) -ForegroundColor Cyan

        try {
            $null = Convert-GroupToClassTeam -GroupId $result.GroupId -DisplayName $result.DisplayName

            # A teamified group shares its id with the team.
            $result.TeamId = $result.GroupId
            $result.Status = 'Created'
            Write-Host ("  Created. Team id: {0}" -f $result.TeamId) -ForegroundColor Green
        }
        catch {
            $result.Status = 'GroupOnly'
            $result.Error = $_.Exception.Message
            Write-Warning ("  Teamification failed: {0}" -f $_.Exception.Message)
        }
    }
}

function Write-ResultSummary {
    <#
    .SYNOPSIS
        Prints the end-of-run summary, calling out groups left un-teamified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[pscustomobject]] $Results
    )

    $createdCount = @($Results | Where-Object { $_.Status -eq 'Created' }).Count
    $whatIfCount = @($Results | Where-Object { $_.Status -eq 'WhatIf' }).Count
    $groupOnly = @($Results | Where-Object { $_.Status -eq 'GroupOnly' })
    $failed = @($Results | Where-Object { $_.Status -eq 'Failed' }).Count

    Write-Host ''
    if ($whatIfCount -gt 0) {
        Write-Host ("Summary (WhatIf): {0} would be created, {1} failed, {2} requested." -f $whatIfCount, $failed, $Results.Count) -ForegroundColor Cyan
        return
    }

    Write-Host ("Summary: {0} created, {1} group-only, {2} failed, {3} requested." -f $createdCount, $groupOnly.Count, $failed, $Results.Count) -ForegroundColor Cyan

    if ($groupOnly.Count -gt 0) {
        Write-Host ''
        Write-Warning 'The following groups were created but could not be teamified. They exist in the tenant and can be retried without recreating them:'
        foreach ($item in $groupOnly) {
            Write-Host ("  - {0}  (group {1})" -f $item.DisplayName, $item.GroupId) -ForegroundColor Yellow
        }
    }
}

Invoke-ClassTeamCreation

#endregion Main
