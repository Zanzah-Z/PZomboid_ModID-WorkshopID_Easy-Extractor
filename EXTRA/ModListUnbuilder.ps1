<#
    Mod List Unbuilder
    -------------------
    The reverse of ModListBuilder: reads mod_list.txt (in the same folder as
    this script) - the

        mods
        {
            mod = modname1,
            mod = modname2,
        }

    format - and writes out a semicolon-separated ID.txt, e.g.:

        modname1;modname2

    Never overwrites: if ID.txt already exists, this writes ID1.txt,
    ID2.txt, etc. instead.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptDir
)

function Get-NonClobberingPath {
    param([string]$Directory, [string]$BaseName, [string]$Extension)
    $candidate = Join-Path $Directory "$BaseName$Extension"
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    $i = 1
    while ($true) {
        $candidate = Join-Path $Directory "$BaseName$i$Extension"
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
        $i++
    }
}

$ScriptDir = $ScriptDir.Trim('"')
try {
    $ScriptDir = ([System.IO.Path]::GetFullPath($ScriptDir)).TrimEnd('\')
} catch {
    $ScriptDir = $ScriptDir.TrimEnd('\')
}

$inFile = Join-Path $ScriptDir 'mod_list.txt'

if (-not (Test-Path -LiteralPath $inFile)) {
    Write-Host "Could not find mod_list.txt here:"
    Write-Host "  $inFile"
    Write-Host ""
    Write-Host "Put your mods { mod = ..., } file there and run this again."
    exit 1
}

$raw = Get-Content -LiteralPath $inFile -Raw
$matches = [regex]::Matches($raw, 'mod\s*=\s*([^,\r\n]+)')
$ids = $matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Where-Object { $_ -ne '' }

if (-not $ids -or $ids.Count -eq 0) {
    Write-Host "mod_list.txt was found but no 'mod = ...' entries could be read out of it."
    exit 1
}

$outFile = Get-NonClobberingPath -Directory $ScriptDir -BaseName 'ID' -Extension '.txt'

Set-Content -LiteralPath $outFile -Value ($ids -join ';') -Encoding UTF8 -Force -NoNewline

Write-Host "Wrote $($ids.Count) mod ID(s) to $(Split-Path -Leaf $outFile)"
