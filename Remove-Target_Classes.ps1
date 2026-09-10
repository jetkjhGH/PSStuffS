<#
Script Name:
Remove-Target_Classes.ps1

Synopsis:
This script is designed to delete a targeted set of classes by using the SectionUsage.csv file.
IMPORTANT!!!!
This will delete all of the classes in the csv file uploaded. There will still be a 30 day window to restore them.

Syntax Examples and Options:
.\Remove-Target_Classes.ps1 -Path "C:\Temp\SectionUsage.csv"

Written By:
Daniel Baumgartner

change Log:
Version 1.0, 6/16/2026 - First Draft
 #>

param (
    [Parameter(Mandatory=$true)]
    [string]$Path
)

Connect-mggraph -scopes "group.readwrite.all"
$SectionUsage = Import-Csv -Path $Path
$i = 0

foreach ($entry in $SectionUsage) {
    write-Progress -Activity "Deleting groups..." -Status "Deleteting($($entry.Name))" -PercentComplete (($i/$SectionUsage.Count)*100)
    $id = $entry.GraphId
    try {
        Remove-MgGroup -GroupId $id
        Write-Host "Deleted group with ID: $id" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to delete group with ID: $id. Error: $_" -ForegroundColor Red
    }
    $i++
}