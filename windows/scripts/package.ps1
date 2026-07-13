#requires -Version 5.1
#
# Publishes the WinUI 3 app self-contained for x64 Release and packages it into
# a per-user Inno Setup installer (windows/scripts/installer.iss) and a portable
# zip. Used by the GitHub Actions CI and release workflows, but you can also run
# it locally from a Visual Studio developer prompt with Inno Setup 6 installed:
#
#     windows\scripts\package.ps1
#
# The finished artifacts are written to windows/release/. The version comes from
# the current git tag (leading `v` stripped) when one is present, otherwise a
# default; pass -Version to override.
#
[CmdletBinding()]
param(
    [string]$Version,
    [string]$Configuration = 'Release',
    [ValidateSet('x64')]
    [string]$Platform = 'x64'
)

$ErrorActionPreference = 'Stop'

$Rid = 'win-x64'
$scriptDir = $PSScriptRoot
$windowsDir = Split-Path -Parent $scriptDir
$projectDir = Join-Path $windowsDir 'app\FriendlyTerminal.App'
$project = Join-Path $projectDir 'FriendlyTerminal.App.csproj'
$releaseDir = Join-Path $windowsDir 'release'
$issScript = Join-Path $scriptDir 'installer.iss'

if (-not $Version) {
    if ($env:GITHUB_REF_TYPE -eq 'tag' -and $env:GITHUB_REF_NAME) {
        $Version = $env:GITHUB_REF_NAME
    } else {
        $tag = $null
        $previousEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $inRepo = git -C $windowsDir rev-parse --is-inside-work-tree 2>$null
            if ("$inRepo".Trim() -eq 'true') {
                $tag = git -C $windowsDir tag --points-at HEAD --list 'v*' 2>$null | Select-Object -First 1
            }
        } catch {
            $tag = $null
        } finally {
            $ErrorActionPreference = $previousEap
        }
        $Version = if ($tag) { $tag } else { '1.2.0' }
    }
}
$Version = ($Version -replace '^[vV]', '').Trim()

Write-Host "Packaging FriendlyTerminal $Version ($Configuration / $Platform / $Rid)"

$publishArgs = @(
    $project,
    '-restore',
    '-t:Publish',
    "-p:Configuration=$Configuration",
    "-p:Platform=$Platform",
    "-p:RuntimeIdentifier=$Rid",
    '-p:SelfContained=true',
    '-p:WindowsAppSDKSelfContained=true',
    '-p:WindowsPackageType=None',
    '-nologo',
    '-v:minimal'
)
& msbuild @publishArgs
if ($LASTEXITCODE -ne 0) { throw "msbuild publish failed with exit code $LASTEXITCODE" }

$binDir = Join-Path $projectDir "bin\$Platform\$Configuration"
$publishDir = Get-ChildItem -Path $binDir -Recurse -Directory -Filter 'publish' -ErrorAction SilentlyContinue |
    Where-Object { $_.Parent.Name -eq $Rid -and (Test-Path (Join-Path $_.FullName 'FriendlyTerminal.App.exe')) } |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $publishDir) { throw "Could not locate $Rid publish output containing FriendlyTerminal.App.exe under $binDir" }
Write-Host "Publish output: $publishDir"

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

$zipPath = Join-Path $releaseDir "FriendlyTerminal-$Version-x64.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$zipStageDir = Join-Path $releaseDir 'zip-stage'
if (Test-Path $zipStageDir) { Remove-Item $zipStageDir -Recurse -Force }
$zipRootDir = Join-Path $zipStageDir 'FriendlyTerminal'
New-Item -ItemType Directory -Force -Path $zipRootDir | Out-Null
try {
    Copy-Item -Path (Join-Path $publishDir '*') -Destination $zipRootDir -Recurse
    Compress-Archive -Path $zipRootDir -DestinationPath $zipPath
} finally {
    Remove-Item $zipStageDir -Recurse -Force
}
Write-Host "Portable archive: $zipPath"

$iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
if (-not (Test-Path $iscc)) {
    $cmd = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($cmd) { $iscc = $cmd.Source } else { throw "ISCC.exe not found. Install Inno Setup 6." }
}

& $iscc "/DAppVersion=$Version" "/DPublishDir=$publishDir" "/DOutputDir=$releaseDir" $issScript
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compile failed with exit code $LASTEXITCODE" }
Write-Host "Installer: $(Join-Path $releaseDir "FriendlyTerminal-Setup-$Version-x64.exe")"
