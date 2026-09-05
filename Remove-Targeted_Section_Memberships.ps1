<#
Script Name:
Remove-Targeted_Section_Memberships.ps1

Synopsis:
This script removes non-owner members from the classes listed in a CSV file. The CSV file must contain a GraphId column.

Syntax Examples and Options:
.\Remove-Targeted_Section_Memberships.ps1 -Path "C:\Temp\SectionUsage.csv"

Written By: 
Daniel Baumgartner

Change Log:
Version 1.0, 8/12/2026 - First Draft
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$Path
)

$classRows = @(Import-Csv -LiteralPath $Path)

if ($classRows.Count -eq 0) {
    throw "The CSV file '$Path' does not contain any classes."
}

if ('GraphId' -notin $classRows[0].PSObject.Properties.Name) {
    throw "The CSV file '$Path' must contain a column named 'GraphId'."
}

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

Connect-mggraph -scopes 'Group.ReadWrite.All' -NoWelcome
$outFile = '.\RemovedStudents.csv'

$count = $groups.Count
Write-Host -ForegroundColor Green "Found $count targeted classes. Starting cleanup - removing members."
$table = @()

# removing memberships
$i = 0
foreach ($group in $groups) {
    Write-Progress -Activity "Removing members for $($group.displayname)..." -Status "Processing($group.displayname)" -PercentComplete (($i/$count)*100)
    $groupId = $group.Id
    $GroupName = $group.DisplayName
    try {
        $owners = Get-MgGroupOwnerAsUser -GroupId $group.Id -All -ErrorAction Stop
        $ownerIds = @($owners | ForEach-Object { $_.Id })
        $members = Get-MgGroupMemberAsUser -GroupId $group.Id -All -ErrorAction Stop

        # Owners are also returned as members; remove only non-owner members.
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

$table | export-csv -path $outFile -NoTypeInformation

Write-Host 'Script complete. Disconnecting Graph.'
Disconnect-Graph