[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RetailPath = "${env:ProgramFiles(x86)}\World of Warcraft\_retail_"
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$retailRoot = (Resolve-Path -LiteralPath $RetailPath).Path
if ((Split-Path -Leaf $retailRoot) -ne '_retail_' -or
    -not (Test-Path -LiteralPath (Join-Path $retailRoot 'WoW.exe'))) {
    throw 'RetailPath must point to the _retail_ directory containing WoW.exe.'
}
$destinationRoot = Join-Path $retailRoot 'Interface\AddOns\kaldo_tweaks'

# Copy runtime files only. Never mirror/delete, or touch WTF/SavedVariables.
$files = @(
    Get-ChildItem -LiteralPath $sourceRoot -File | Where-Object Extension -In '.lua', '.toc'
    foreach ($directory in @('modules', 'data', 'assets')) {
        Get-ChildItem -LiteralPath (Join-Path $sourceRoot $directory) -File -Recurse
    }
)
$copied = 0
foreach ($file in $files) {
    $relative = $file.FullName.Substring($sourceRoot.Length + 1)
    $destination = Join-Path $destinationRoot $relative
    if ($PSCmdlet.ShouldProcess($destination, 'Copy addon file')) {
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne
            (Get-FileHash -LiteralPath $destination).Hash) {
            throw "Copy verification failed: $relative"
        }
        $copied++
    }
}
Write-Host "$copied files deployed to $destinationRoot"
Write-Host 'In WoW: /reload (restart the client if the TOC file list changed).'
