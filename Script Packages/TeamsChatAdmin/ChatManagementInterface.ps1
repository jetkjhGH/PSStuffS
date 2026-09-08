#requires -Version 7.0

[CmdletBinding()]
param(
	[Parameter()]
	[ValidateSet('Terminal', 'Windows', 'Auto')]
	[string]$UiMode = 'Auto',

	[Parameter()]
	[switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'src\TeamsChatAdmin.psd1'
if (-not (Test-Path -LiteralPath $moduleManifestPath)) {
	throw ('TeamsChatAdmin module manifest was not found at {0}. Keep ChatManagementInterface.ps1 beside the src folder.' -f $moduleManifestPath)
}

$missingGraphCommands = @(@(
	'Get-MgContext',
	'Invoke-MgGraphRequest'
) | Where-Object { -not (Get-Command -Name $_ -ErrorAction SilentlyContinue) })

if ($missingGraphCommands.Count -gt 0) {
	Write-Warning ('Microsoft Graph PowerShell SDK command(s) not found: {0}. Install Microsoft.Graph and connect with Connect-MgGraph before using live chat inspection.' -f ($missingGraphCommands -join ', '))
}

Import-Module $moduleManifestPath -Force

Start-TeamsChatAdmin -UiMode $UiMode -NonInteractive:$NonInteractive