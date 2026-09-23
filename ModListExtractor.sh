#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1="$SCRIPT_DIR/ModListExtractor.ps1"

if [ ! -f "$PS1" ]; then
    echo "Could not find ModListExtractor.ps1 next to this script."
    echo "Both files need to be in the same folder."
    exit 1
fi

if ! command -v pwsh >/dev/null 2>&1; then
    echo "pwsh not found - see README.md for the solution, then run this tool again." > "$SCRIPT_DIR/_SetupCheck.txt"
    echo "PowerShell (pwsh) was not found on this system."
    echo ""
    echo "See README.md for how to install it, then run this script again."
    exit 1
fi

pwsh -NoProfile -File "$PS1" -ScriptDir "$SCRIPT_DIR"
