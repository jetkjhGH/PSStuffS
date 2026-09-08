<#
.SYNOPSIS
 Removes every non-owner member from Microsoft 365 groups listed in a CSV file.

.DESCRIPTION
 Imports a CSV containing a GraphId column, resolves each group's owners and user members,
 and removes members whose IDs are not in the owner list. It writes successful removals to
 RemovedStudents.csv in the current directory.

 This script changes group membership and has no -WhatIf or confirmation support. Review the
 input CSV carefully, test with one non-production class, and run only while connected to the
 intended tenant. Owners are preserved because owners are also returned in the member list.

 Unlike the repository's reporting and creation scripts, this legacy utility initiates its
 own delegated Graph connection and disconnects at the end.

.PARAMETER Path
 Path to a CSV file. GraphId is required. Name is optional and is used only for display and
 report output; when absent, GraphId is used as the display label.

.EXAMPLE
 .\Remove-Targeted_Section_Memberships.ps1 -Path 'C:\Temp\SectionUsage.csv'

.NOTES
 Required delegated Graph scope: Group.ReadWrite.All

 Written by Daniel Baumgartner.
 Version 1.0, 8/12/2026 - First draft.
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$Path
)

# Import and validate the entire target list before connecting or removing any membership.
$classRows = @(Import-Csv -LiteralPath $Path)

if ($classRows.Count -eq 0) {
    throw "The CSV file '$Path' does not contain any classes."
}

if ('GraphId' -notin $classRows[0].PSObject.Properties.Name) {
    throw "The CSV file '$Path' must contain a column named 'GraphId'."
}

# Normalize the required Graph IDs and preserve an optional administrator-friendly Name.
$groups = @(
    $classRows |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.GraphId) } |
        ForEach-Object {
            [PSCustomObject]@{
                Id = $_.GraphId.Trim()
                DisplayName = if ($_.PSObject.Properties.Name -contains 'Name' -and -not [string]::IsNullOrWhiteSpace($_.Name)) {
                    $_.Name
                }
                else {
                    $_.GraphId.Trim()
                }
            }
        }
)

if ($groups.Count -eq 0) {
    throw "The CSV file '$Path' does not contain any nonblank GraphId values."
}

# Administrator adjustment: change the output path when the removal audit must be retained
# outside the current working directory. Keep the CSV schema stable for downstream review.
$outFile = '.\RemovedStudents.csv'

# This legacy utility signs in interactively. Confirm the account and tenant shown by the
# authentication flow before allowing the script to continue.
Connect-MgGraph -Scopes 'Group.ReadWrite.All' -NoWelcome

$count = $groups.Count
Write-Host -ForegroundColor Green "Found $count targeted classes. Starting cleanup - removing members."
$table = @()

# Process classes independently. A group-level failure warns and continues with later groups.
$i = 0
foreach ($group in $groups) {
    Write-Progress -Activity "Removing members for $($group.displayname)..." -Status "Processing($group.displayname)" -PercentComplete (($i/$count)*100)
    $groupId = $group.Id
    $GroupName = $group.DisplayName
    try {
        $owners = Get-MgGroupOwnerAsUser -GroupId $group.Id -All -ErrorAction Stop
        $ownerIds = @($owners | ForEach-Object { $_.Id })
        $members = Get-MgGroupMemberAsUser -GroupId $group.Id -All -ErrorAction Stop

        # Owners are also returned as members; this exclusion is the safety boundary that
        # prevents owner removal and should not be weakened for routine use.
        $membersToRemove = $members | Where-Object { $_.Id -and ($_.Id -notin $ownerIds) }

        foreach ($member in $membersToRemove) {
            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $member.Id -ErrorAction Stop
            $memberId = $member.Id
            $MemberName = $member.DisplayName
            
            $row = [PSCustomObject]@{
                GroupId = $groupId
                GroupName = $GroupName
                MemberId = $memberId
                MemberName = $MemberName
            }
            $table += $row

        }
    }
    catch {
        Write-Warning "Couldn't process owners/members for group: $($group.DisplayName)"
    }

    $i++
}

# The audit contains only successful removal calls; group-level warnings are console output.
$table | Export-Csv -Path $outFile -NoTypeInformation

Write-Host 'Script complete. Disconnecting Graph.'
Disconnect-Graph