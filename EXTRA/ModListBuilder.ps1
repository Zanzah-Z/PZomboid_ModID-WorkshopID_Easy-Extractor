<#
    Mod List Builder
    ----------------
    Reads a semicolon-separated list of PZ Mod IDs from ID.txt (in the same
    folder as this script) and writes mod_list.txt in the same folder,
    formatted as:

        mods
        {
            mod = modname1,
            mod = modname2,
        }

    ID.txt can have the IDs all on one line or spread across several lines -
    either way works, they just need to be separated by semicolons and/or
    line breaks.

    Never overwrites: if mod_list.txt already exists, this writes
    mod_list1.txt, mod_list2.txt, etc. instead.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptDir
)

# Flip to $true if you want duplicate mod IDs removed automatically.
$RemoveDuplicates = $false

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

$inFile = Join-Path $ScriptDir 'ID.txt'
$outFile = Get-NonClobberingPath -Directory $ScriptDir -BaseName 'mod_list' -Extension '.txt'

if (-not (Test-Path -LiteralPath $inFile)) {
    Write-Host "Could not find ID.txt here:"
    Write-Host "  $inFile"
    Write-Host ""
    Write-Host "Put your semicolon-separated mod ID list in that file and run this again."
    exit 1
}

$raw = Get-Content -LiteralPath $inFile -Raw
$ids = $raw -split '[;\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

if ($RemoveDuplicates) {
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $ids = $ids | Where-Object { $seen.Add($_) }
}

if (-not $ids -or $ids.Count -eq 0) {
    Write-Host "ID.txt was found but no mod IDs could be read out of it."
    exit 1
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('mods')
$lines.Add('{')
foreach ($id in $ids) {
    $lines.Add("    mod = $id,")
}
$lines.Add('}')

Set-Content -LiteralPath $outFile -Value $lines -Encoding UTF8 -Force

Write-Host "Wrote $($ids.Count) mod(s) to $(Split-Path -Leaf $outFile)"
