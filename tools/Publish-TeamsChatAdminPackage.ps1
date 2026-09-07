#requires -Version 5.1

[CmdletBinding()]
param(
	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$OutputPath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'dist'),

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]$PackageName = 'TeamsChatAdmin',

	[Parameter()]
	[switch]$NoZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-TeamsChatAdminPackageScript {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$Path
	)

	$errors = $null
	[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors) | Out-Null
	if ($errors.Count -gt 0) {
		$errorText = ($errors | ForEach-Object { $_.Message }) -join '; '
		throw ('PowerShell parser validation failed for {0}: {1}' -f $Path, $errorText)
	}
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path -Path $repositoryRoot -ChildPath 'src\TeamsChatAdmin.psd1'
$correctedLauncherPath = Join-Path -Path $repositoryRoot -ChildPath 'ChatManagementInterface.ps1'
$runbookPath = Join-Path -Path $repositoryRoot -ChildPath 'docs\TeamsChatAdmin-Distribution.md'
$sourceRoot = Join-Path -Path $repositoryRoot -ChildPath 'src'

foreach ($requiredPath in @($manifestPath, $correctedLauncherPath, $runbookPath, $sourceRoot)) {
	if (-not (Test-Path -LiteralPath $requiredPath)) {
		throw ('Required packaging input was not found: {0}' -f $requiredPath)
	}
}

$manifestData = Import-PowerShellDataFile -Path $manifestPath
$moduleVersion = [string]$manifestData.ModuleVersion
if ([string]::IsNullOrWhiteSpace($moduleVersion)) {
	throw 'Unable to read ModuleVersion from src\TeamsChatAdmin.psd1.'
}

$packageFolderName = '{0}-{1}' -f $PackageName, $moduleVersion
$stagingRoot = Join-Path -Path $OutputPath -ChildPath $packageFolderName
$zipPath = Join-Path -Path $OutputPath -ChildPath ('{0}.zip' -f $packageFolderName)

if (Test-Path -LiteralPath $stagingRoot) {
	Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

New-Item -Path $stagingRoot -ItemType Directory -Force | Out-Null

Copy-Item -LiteralPath $correctedLauncherPath -Destination $stagingRoot -Force
Copy-Item -LiteralPath $runbookPath -Destination (Join-Path -Path $stagingRoot -ChildPath 'README_DISTRIBUTION.md') -Force
Copy-Item -LiteralPath $sourceRoot -Destination (Join-Path -Path $stagingRoot -ChildPath 'src') -Recurse -Force

$requiredPackagePaths = @(
	'ChatManagementInterface.ps1',
	'README_DISTRIBUTION.md',
	'src\TeamsChatAdmin.psd1',
	'src\TeamsChatAdmin.psm1'
)

foreach ($relativePath in $requiredPackagePaths) {
	$fullPath = Join-Path -Path $stagingRoot -ChildPath $relativePath
	if (-not (Test-Path -LiteralPath $fullPath)) {
		throw ('Packaged output is missing required file: {0}' -f $relativePath)
	}
}

$scriptFiles = Get-ChildItem -Path $stagingRoot -Recurse -Include '*.ps1', '*.psm1', '*.psd1'
foreach ($scriptFile in $scriptFiles) {
	Test-TeamsChatAdminPackageScript -Path $scriptFile.FullName
}

if (-not $NoZip) {
	if (Test-Path -LiteralPath $zipPath) {
		Remove-Item -LiteralPath $zipPath -Force
	}

	Compress-Archive -Path (Join-Path -Path $stagingRoot -ChildPath '*') -DestinationPath $zipPath -Force
	if (-not (Test-Path -LiteralPath $zipPath)) {
		throw ('Package zip was not created: {0}' -f $zipPath)
	}
}

[pscustomobject]@{
	PackageName = $packageFolderName
	ModuleVersion = $moduleVersion
	StagingRoot = $stagingRoot
	ZipPath = if ($NoZip) { $null } else { $zipPath }
}