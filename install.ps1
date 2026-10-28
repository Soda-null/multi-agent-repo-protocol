# Windows entry point: runs install.sh with the bash that ships with Git for Windows.
#
#   .\install.ps1 C:\path\to\your\repo
#   .\install.ps1 C:\path\to\your\repo -DryRun
#
# The hooks and scripts are shell scripts; Git for Windows runs them with its own bash,
# so nothing else is needed. WSL's bash is deliberately not used: it sees a different
# file system and a different git.
param(
    [Parameter(Mandatory = $true)][string]$Target,
    [switch]$DryRun
)
$ErrorActionPreference = "Stop"

$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) { throw "git not found. Install Git for Windows: https://git-scm.com/download/win" }
# git.exe lives in <Git>\cmd or <Git>\bin (or <Git>\mingw64\bin); bash.exe in <Git>\bin.
$bash = $null
$dir = Split-Path $git
for ($i = 0; $i -lt 4 -and $dir; $i++) {
    $candidate = Join-Path $dir "bin\bash.exe"
    if (Test-Path $candidate) { $bash = $candidate; break }
    $dir = Split-Path $dir
}
if (-not $bash) { throw "Git Bash not found near $git. Reinstall Git for Windows with Git Bash." }

$script = (Join-Path $PSScriptRoot "install.sh") -replace '\\', '/'
$repo = (Resolve-Path $Target).Path -replace '\\', '/'
$bashArgs = @($script, $repo)
if ($DryRun) { $bashArgs += "--dry-run" }
& $bash @bashArgs
exit $LASTEXITCODE
