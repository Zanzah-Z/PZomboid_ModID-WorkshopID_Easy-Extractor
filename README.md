# Mod List Extractor Created by Zanzah

Works on Windows/MacOS/Linux/Headless (Discord: Zanzah#5137 if you run into any issues.)

https://ko-fi.com/zanzah_z

https://www.Zanzah.com/donate (PayPal)

Scans your Project Zomboid Workshop downloads and sorts every workshop
folder into one of three buckets, writing whatever's needed for each:

| Output | What it is | Written when |
|---|---|---|
| `_modsID#.txt` | `Mods=id1;id2;id3` | at least one folder had exactly one mod ID |
| `_WorkshopID#.txt` | `WorkshopItems=wid1;wid2;wid3` | at least one folder had a usable ID |
| `Skipped#/` | a folder of `.lnk` shortcuts, one per conflicted workshop folder | at least one folder had *more than one* distinct mod ID |
| `Errors#.txt` | one line per folder with no mod ID at all | at least one folder had *zero* mod IDs |

(`_modsID`/`_WorkshopID` are underscore-prefixed so they sort to the top
and are easy to find among your Workshop Item folders.)

## Where to run it

It **must** be run from inside:

```
...\steamapps\workshop\content\108600\
```

`108600` is Project Zomboid's own Steam AppID - that's the folder whose
immediate subfolders are individual Workshop Item IDs:

```
steamapps\workshop\content\108600\<WorkshopItemID>\mods\<ModName>\mod.info
```

Run it from anywhere else and it'll explain why and stop, rather than
writing a wrong list.

## Requirements

Works on Windows, Linux, and macOS (including headless Linux servers) -
one shared `ModListExtractor.ps1` does the actual work; pick the launcher
for your OS.

### Windows

PowerShell 5.1 comes built into Windows 10, Windows 11, and Server 2016+
- nothing to install. `ModListExtractor.bat` uses it automatically.

If it's genuinely missing (e.g. a stripped-down Server Core install),
install PowerShell 7 instead - the `.bat` falls back to it automatically
if present:
- **Winget (recommended):** open PowerShell or Command Prompt and run
  `winget install --id Microsoft.PowerShell --source winget`
- **Manual:** download the `win-x64.msi` from
  https://github.com/PowerShell/PowerShell/releases/latest and run it.

### Linux (including headless servers)

Needs PowerShell 7+ (`pwsh`) - not installed by default on any distro.

- **Debian/Ubuntu:**
  ```
  sudo apt-get update
  sudo apt-get install -y wget apt-transport-https software-properties-common
  wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  sudo apt-get update
  sudo apt-get install -y powershell
  ```
- **Other distros (Fedora, RHEL, Alpine, Arch, etc.):** exact per-distro
  steps at https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
- Verify it worked: `pwsh --version`

Works the same way over SSH on a headless dedicated server - no desktop
environment needed.

### macOS

Needs PowerShell 7+ (`pwsh`).

- **Homebrew (recommended):** `brew install --cask powershell` (needs
  Homebrew first - https://brew.sh)
- **Manual:** download the `.pkg` from
  https://github.com/PowerShell/PowerShell/releases/latest
- Verify it worked: `pwsh --version`

### Running it

**Windows:** copy `ModListExtractor.bat` and `ModListExtractor.ps1` into
`steamapps\workshop\content\108600\` and double-click the `.bat`.

**Linux / macOS:** copy `ModListExtractor.sh` and `ModListExtractor.ps1`
into `steamapps/workshop/content/108600/`, then:

```
chmod +x ModListExtractor.sh
./ModListExtractor.sh
```

Either way, read the console output, then check whichever of the files
below got written.

### If something's missing

If PowerShell/`pwsh` can't be found at all, or the version found is too
old (below 5.0), the tool prints what's wrong and points back to this
file - and also writes that same message to `_SetupCheck.txt` next to the
scripts, in case the console closes too fast to read or you're checking
back later on a headless box. That file gets deleted automatically the
next time the tool runs successfully, so its presence always means
"something's still wrong" - if it's gone, you're clear.

## The three buckets, per workshop folder

Every `*.info` file's `id=` value is grouped by which top-level (Workshop
Item ID) folder it's under:

- **Exactly one distinct ID** (even across several `.info` files, e.g.
  version-variant subfolders) → safe. Goes into `_modsID#.txt` once (no
  duplicates) and `_WorkshopID#.txt`.
- **More than one distinct ID** under the same folder (e.g. an old
  patch-version ID left behind alongside a current one) → conflict. Left
  out of `_modsID#.txt`, but still included in `_WorkshopID#.txt` (the
  Workshop ID itself is never ambiguous). A pointer to that exact folder
  is dropped in `Skipped#/` so you can jump straight to it and sort out
  which ID is right by hand - a `.lnk` shortcut on Windows, a symlink on
  Linux/macOS. Either way nothing is copied or moved, so Steam's own
  tracking of the folder is untouched.
- **Zero mod IDs found** (no `*.info` file, or none with an `id=` line)
  → error. Left out of *both* `_modsID#.txt` and `_WorkshopID#.txt`, and
  logged to `Errors#.txt`.

## Never overwrites, and everything from one run shares a number

Before writing anything, the tool checks the highest number already used
across `_modsID#.txt`, `_WorkshopID#.txt`, `Errors#.txt`, and `Skipped#/`
combined, then uses the next number for *all* of them this run - so one
run's outputs always share the same suffix, even if only some of the four
existed before. Example: if `_modsID2.txt` exists but `_WorkshopID.txt`
(unnumbered) is the newest `_WorkshopID` file, the next run writes
`_modsID3.txt`, `_WorkshopID3.txt`, `Errors3.txt`, and `Skipped3/` - never
`WorkshopID1`. The very first run has no suffix at all.

## Settings

Near the top of `ModListExtractor.ps1`:

- `$RemoveDuplicateMods` / `$RemoveDuplicateWorkshopIds` (default
  `$false`) - drop duplicate IDs that show up across *different*
  Workshop Item folders (rare, but possible).
- `$ExpectedAppId` (default `'108600'`) - only relevant if you ever reuse
  this for a different Steam game.

## Related tools

- **ModListBuilder** - turns a semicolon-separated `ID.txt` into a
  `mods { mod = ..., }` block (`mod_list.txt`).
- **ModListUnbuilder** - the reverse: turns a `mod_list.txt` block back
  into a semicolon-separated `ID.txt`.

Note: those two tools' `ID.txt` format (bare `id1;id2;id3`, no `Mods=`
prefix) is different from this tool's `_modsID#.txt` (`Mods=id1;id2;id3`)
- they were built for a different step in the workflow, so double check
which format you need before reusing a file between tools.
