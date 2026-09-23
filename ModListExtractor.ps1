param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptDir
)

$RemoveDuplicateMods = $false
$RemoveDuplicateWorkshopIds = $false
$ExpectedAppId = '108600'

function Get-TrailingNumber {
    param([string]$Name, [string]$Prefix)
    if ($Name.Length -lt $Prefix.Length) { return -1 }
    $suffixPart = $Name.Substring($Prefix.Length)
    if ($suffixPart -eq '') { return 0 }
    if ($suffixPart -match '^\d+$') { return [int]$suffixPart }
    return -1
}

if (-not (Test-Path variable:IsWindows)) {
    $IsWindows = $true
    $IsLinux = $false
    $IsMacOS = $false
}

$ScriptDir = $ScriptDir.Trim('"')
try {
    $ScriptDir = ([System.IO.Path]::GetFullPath($ScriptDir)).TrimEnd('\', '/')
} catch {
    $ScriptDir = $ScriptDir.TrimEnd('\', '/')
}

Write-Host "Mod List Extractor" -ForegroundColor Cyan
Write-Host "==================="
Write-Host "Scanning: $ScriptDir"

$setupCheckFile = Join-Path $ScriptDir '_SetupCheck.txt'
$MinPSMajor = 5
if ($PSVersionTable.PSVersion.Major -lt $MinPSMajor) {
    $msg = "PowerShell version $($PSVersionTable.PSVersion) found, but $MinPSMajor.0 or newer is required. See README.md for how to update, then run this tool again."
    Write-Host ""
    Write-Host $msg -ForegroundColor Red
    try { Set-Content -LiteralPath $setupCheckFile -Value $msg -Encoding UTF8 -Force } catch {}
    exit 1
}
if (Test-Path -LiteralPath $setupCheckFile) {
    Remove-Item -LiteralPath $setupCheckFile -Force -ErrorAction SilentlyContinue
}

$sep = [System.IO.Path]::DirectorySeparatorChar
$expectedPattern = "[\\/]steamapps[\\/]workshop[\\/]content[\\/]$ExpectedAppId`$"
if ($ScriptDir -notmatch $expectedPattern) {
    Write-Host ""
    Write-Host "This tool is meant to be run from inside:" -ForegroundColor Yellow
    Write-Host "  ...${sep}steamapps${sep}workshop${sep}content${sep}$ExpectedAppId${sep}" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "That's Project Zomboid's own Workshop AppID folder. The layout looks like:" -ForegroundColor Yellow
    Write-Host "  steamapps${sep}workshop${sep}content${sep}$ExpectedAppId${sep}<WorkshopItemID>${sep}mods${sep}<ModName>${sep}mod.info" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Right now this is running from:" -ForegroundColor Yellow
    Write-Host "  $ScriptDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Move both files into steamapps${sep}workshop${sep}content${sep}$ExpectedAppId${sep} and run this again." -ForegroundColor Yellow
    exit 1
}
Write-Host "Folder OK." -ForegroundColor Green

Write-Host ""
Write-Host "Scanning for *.info files..."
$infoFiles = Get-ChildItem -LiteralPath $ScriptDir -Recurse -Filter *.info -File -ErrorAction SilentlyContinue

$groups = [ordered]@{}
foreach ($file in $infoFiles) {
    $idLine = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^\s*id\s*=' } | Select-Object -First 1
    if ($idLine) {
        $val = ($idLine -replace '^\s*id\s*=\s*', '').Trim()
        if ($val -ne '') {
            $rel = $file.FullName.Substring($ScriptDir.Length).TrimStart('\', '/')
            $segments = $rel -split '[\\/]+'
            $groupKey = if ($segments.Count -gt 1) { $segments[0] } else { '(top level)' }
            if (-not $groups.Contains($groupKey)) {
                $groups[$groupKey] = New-Object System.Collections.Generic.HashSet[string]
            }
            [void]$groups[$groupKey].Add($val)
            Write-Host "  [$groupKey / $($file.Name)] -> $val" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Scanning top-level folders for Workshop IDs..."
$allWorkshopFolders = @(Get-ChildItem -LiteralPath $ScriptDir -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d+$' } |
    Sort-Object { [int64]$_.Name })

$modIds = New-Object System.Collections.Generic.List[string]
$workshopIds = New-Object System.Collections.Generic.List[string]
$conflictFolders = New-Object System.Collections.Generic.List[string]
$errorLines = New-Object System.Collections.Generic.List[string]

foreach ($folder in $allWorkshopFolders) {
    $key = $folder.Name
    if ($groups.Contains($key)) {
        $distinctIds = $groups[$key]
        if ($distinctIds.Count -eq 1) {
            $modIds.Add(($distinctIds | Select-Object -First 1))
            $workshopIds.Add($key)
        } else {
            $msg = "Skipped modID extraction from folder $key ($($distinctIds -join ', ')), needs manual extraction."
            Write-Host "  $msg" -ForegroundColor Yellow
            $conflictFolders.Add($key)
            $workshopIds.Add($key)
        }
    } else {
        $msg = "No mod ID found in workshop folder $key - excluded from both output files."
        Write-Host "  $msg" -ForegroundColor Red
        $errorLines.Add($msg)
    }
}

if ($RemoveDuplicateMods) {
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $modIds = [System.Collections.Generic.List[string]]($modIds | Where-Object { $seen.Add($_) })
}
if ($RemoveDuplicateWorkshopIds) {
    $seen2 = New-Object System.Collections.Generic.HashSet[string]
    $workshopIds = [System.Collections.Generic.List[string]]($workshopIds | Where-Object { $seen2.Add($_) })
}

Write-Host ""
Write-Host "Found $($allWorkshopFolders.Count) workshop folder(s): $($modIds.Count) safe, $($conflictFolders.Count) with ID conflicts, $($errorLines.Count) with no ID found."

$maxNum = -1
Get-ChildItem -LiteralPath $ScriptDir -Filter '_modsID*.txt' -File -ErrorAction SilentlyContinue |
    ForEach-Object { $n = Get-TrailingNumber -Name $_.BaseName -Prefix '_modsID'; if ($n -gt $maxNum) { $maxNum = $n } }
Get-ChildItem -LiteralPath $ScriptDir -Filter '_WorkshopID*.txt' -File -ErrorAction SilentlyContinue |
    ForEach-Object { $n = Get-TrailingNumber -Name $_.BaseName -Prefix '_WorkshopID'; if ($n -gt $maxNum) { $maxNum = $n } }
Get-ChildItem -LiteralPath $ScriptDir -Filter 'Errors*.txt' -File -ErrorAction SilentlyContinue |
    ForEach-Object { $n = Get-TrailingNumber -Name $_.BaseName -Prefix 'Errors'; if ($n -gt $maxNum) { $maxNum = $n } }
Get-ChildItem -LiteralPath $ScriptDir -Filter 'Skipped*' -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { $n = Get-TrailingNumber -Name $_.Name -Prefix 'Skipped'; if ($n -gt $maxNum) { $maxNum = $n } }

$batchNum = $maxNum + 1
$suffix = if ($batchNum -eq 0) { '' } else { "$batchNum" }

$anyWritten = $false

if ($modIds.Count -gt 0) {
    $idOut = Join-Path $ScriptDir "_modsID$suffix.txt"
    Set-Content -LiteralPath $idOut -Value ("Mods=" + ($modIds -join ';')) -Encoding UTF8 -Force -NoNewline
    Write-Host ""
    Write-Host "Wrote $($modIds.Count) mod ID(s) to $(Split-Path -Leaf $idOut)" -ForegroundColor Cyan
    $anyWritten = $true
} else {
    Write-Host ""
    Write-Host "No usable mod IDs found - _modsID$suffix.txt not written." -ForegroundColor Yellow
}

if ($workshopIds.Count -gt 0) {
    $wIdOut = Join-Path $ScriptDir "_WorkshopID$suffix.txt"
    Set-Content -LiteralPath $wIdOut -Value ("WorkshopItems=" + ($workshopIds -join ';')) -Encoding UTF8 -Force -NoNewline
    Write-Host "Wrote $($workshopIds.Count) Workshop ID(s) to $(Split-Path -Leaf $wIdOut)" -ForegroundColor Cyan
    $anyWritten = $true
} else {
    Write-Host "No usable Workshop IDs found - _WorkshopID$suffix.txt not written." -ForegroundColor Yellow
}

if ($conflictFolders.Count -gt 0) {
    $skipDir = Join-Path $ScriptDir "Skipped$suffix"
    [System.IO.Directory]::CreateDirectory($skipDir) | Out-Null
    try {
        if ($IsWindows) {
            $shell = New-Object -ComObject WScript.Shell
            foreach ($key in $conflictFolders) {
                $target = Join-Path $ScriptDir $key
                if (Test-Path -LiteralPath $target) {
                    $lnk = $shell.CreateShortcut((Join-Path $skipDir "$key.lnk"))
                    $lnk.TargetPath = $target
                    $lnk.Save()
                }
            }
        } else {
            foreach ($key in $conflictFolders) {
                $target = Join-Path $ScriptDir $key
                if (Test-Path -LiteralPath $target) {
                    New-Item -ItemType SymbolicLink -Path (Join-Path $skipDir $key) -Target $target -Force -ErrorAction Stop | Out-Null
                }
            }
        }
        Write-Host "Wrote $($conflictFolders.Count) shortcut(s) to $(Split-Path -Leaf $skipDir)$sep - open that folder and use the shortcuts to jump straight to each workshop folder needing manual review. Nothing was copied or moved." -ForegroundColor Cyan
    } catch {
        Write-Host "Could not create shortcuts ($($_.Exception.Message)). Folders needing manual review:" -ForegroundColor Yellow
        foreach ($key in $conflictFolders) { Write-Host "  $key" -ForegroundColor Yellow }
    }
    $anyWritten = $true
}

if ($errorLines.Count -gt 0) {
    $errOut = Join-Path $ScriptDir "Errors$suffix.txt"
    Set-Content -LiteralPath $errOut -Value $errorLines -Encoding UTF8 -Force
    Write-Host "Wrote $($errorLines.Count) error(s) to $(Split-Path -Leaf $errOut)" -ForegroundColor Cyan
    $anyWritten = $true
}

if (-not $anyWritten) {
    Write-Host ""
    Write-Host "Nothing found to write." -ForegroundColor Yellow
}
