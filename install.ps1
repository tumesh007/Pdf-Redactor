#Requires -Version 5.1
<#
.SYNOPSIS
    Installs PDF Redactor on Windows: locates or installs Python 3.12+,
    creates a virtual environment, and installs every dependency from
    requirements.txt (PySide6, PyMuPDF, Pillow, PyInstaller, pytest).

.DESCRIPTION
    Equivalent to install.bat, but written for PowerShell with proper
    error handling and an automatic Python install path via winget
    when no suitable Python is already on PATH.

.USAGE
    From a PowerShell prompt, in the project folder:
        .\install.ps1

    If Windows blocks the script from running (execution policy),
    either right-click install.ps1 -> "Run with PowerShell", or run:
        powershell -ExecutionPolicy Bypass -File .\install.ps1

    If auto-detection can't find your Python install, point at it
    directly and skip detection entirely:
        .\install.ps1 -PythonPath "C:\Users\you\AppData\Local\Programs\Python\Python312\python.exe"
#>

[CmdletBinding()]
param(
    [switch]$SkipPythonAutoInstall,
    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'
$RequiredMajor = 3
$RequiredMinor = 12

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Err {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Test-PythonCandidate {
    <#
        Probes one candidate Python command and returns a diagnostic
        object explaining what happened - not just pass/fail - so a
        failed search can be explained to the user instead of being a
        silent black box:

            @{ Ok = $true;  Version = "3.12"; ResolvedPath = ... }
            @{ Ok = $false; Reason = "not found on PATH" }
            @{ Ok = $false; Reason = "resolves to a Microsoft Store alias
                                       stub, not a real Python install";
               ResolvedPath = "...\WindowsApps\python.exe" }
            @{ Ok = $false; Reason = "found but failed to run: <error>" }
    #>
    param([string]$Command, [string[]]$ExtraArgs = @())

    $cmdInfo = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmdInfo) {
        return @{ Ok = $false; Reason = "not found on PATH" }
    }

    $resolvedPath = $cmdInfo.Source
    if ($resolvedPath -and $resolvedPath -match '\\WindowsApps\\') {
        return @{
            Ok = $false
            Reason = "resolves to a Microsoft Store 'App execution alias' stub, not a real Python install"
            ResolvedPath = $resolvedPath
        }
    }

    try {
        $args = $ExtraArgs + @('-c', 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        $output = & $Command @args 2>&1
        $outputText = ($output | Out-String)
        # Windows' "App execution alias" stub for python.exe/python3.exe exits
        # with code 9009 and/or prints a "Microsoft Store" message instead of
        # actually running Python - detect this by behavior too, not just by
        # path, since the resolved path isn't always available/conclusive.
        if ($LASTEXITCODE -eq 9009 -or $outputText -match 'Microsoft Store') {
            return @{
                Ok = $false
                Reason = "resolves to a Microsoft Store 'App execution alias' stub, not a real Python install"
                ResolvedPath = $resolvedPath
            }
        }
        if ($LASTEXITCODE -ne 0 -or -not $output) {
            return @{
                Ok = $false
                Reason = "found but failed to run (exit $LASTEXITCODE): $outputText".Trim()
                ResolvedPath = $resolvedPath
            }
        }
        return @{ Ok = $true; Version = ($output | Select-Object -Last 1).ToString().Trim(); ResolvedPath = $resolvedPath }
    } catch {
        return @{ Ok = $false; Reason = "found but threw an error: $($_.Exception.Message)"; ResolvedPath = $resolvedPath }
    }
}

function Find-PythonInCommonInstallDirs {
    <#
        Last-resort fallback: scans well-known install locations
        directly by filesystem path, bypassing PATH/Get-Command
        entirely, in case Python is installed but PATH doesn't (yet,
        or ever will) point to it. Returns @{ Command; Args; Version }
        on success, or $null with entries appended to $script:Diagnostics
        on failure.
    #>
    $searchRoots = @()
    if ($env:LocalAppData) {
        $searchRoots += (Join-Path $env:LocalAppData 'Programs\Python')
    }
    $searchRoots += 'C:\Program Files'
    $searchRoots += 'C:\Program Files (x86)'
    $searchRoots += 'C:\'
    $searchRoots = $searchRoots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    $checked = 0
    foreach ($root in $searchRoots) {
        # 'Python*' (not just 'Python3*') to also catch e.g. a bare "Python312"
        # folder directly under C:\, or unusual naming from third-party installers.
        $pythonDirs = Get-ChildItem -Path $root -Directory -Filter 'Python*' -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($dir in $pythonDirs) {
            $exe = Join-Path $dir.FullName 'python.exe'
            if (-not (Test-Path $exe)) { continue }
            $checked++
            $result = Test-PythonCandidate -Command $exe -ExtraArgs @()
            if (-not $result.Ok) {
                $script:Diagnostics += "  - $exe : $($result.Reason)"
                continue
            }
            $parts = $result.Version -split '\.'
            $major = [int]$parts[0]
            $minor = [int]$parts[1]
            if ($major -gt $RequiredMajor -or ($major -eq $RequiredMajor -and $minor -ge $RequiredMinor)) {
                return @{ Command = $exe; Args = @(); Version = $result.Version }
            }
            $script:Diagnostics += "  - $exe : found Python $($result.Version), but need $RequiredMajor.$RequiredMinor+"
        }
    }
    if ($checked -eq 0) {
        $script:Diagnostics += "  - no python.exe found under: $($searchRoots -join ', ')"
    }
    return $null
}

function Find-Python {
    <#
        Searches common Windows Python entry points for one that meets
        the minimum version, preferring the 'py' launcher with an
        explicit version request (most reliable on Windows), then
        falls back to whatever 'python'/'python3' resolves to on PATH,
        and finally scans well-known install directories directly by
        filesystem path (see Find-PythonInCommonInstallDirs) in case
        PATH itself is stale or wrong for this session.

        Every failed check is appended to $script:Diagnostics (reset by
        the caller before invoking this) so a total failure can be
        explained to the user in detail instead of being a black box.
        Returns @{ Command = ...; Args = ...; Version = ... } or $null.
    #>
    $candidates = @(
        @{ Command = 'py'; Args = @('-3.12') },
        @{ Command = 'py'; Args = @() },
        @{ Command = 'python3.12'; Args = @() },
        @{ Command = 'python'; Args = @() },
        @{ Command = 'python3'; Args = @() }
    )

    foreach ($c in $candidates) {
        $label = "$($c.Command) $($c.Args -join ' ')".Trim()
        $result = Test-PythonCandidate -Command $c.Command -ExtraArgs $c.Args
        if (-not $result.Ok) {
            $pathNote = if ($result.ResolvedPath) { " (resolved to: $($result.ResolvedPath))" } else { "" }
            $script:Diagnostics += "  - '$label' : $($result.Reason)$pathNote"
            continue
        }
        $parts = $result.Version -split '\.'
        $major = [int]$parts[0]
        $minor = [int]$parts[1]
        if ($major -gt $RequiredMajor -or ($major -eq $RequiredMajor -and $minor -ge $RequiredMinor)) {
            return @{ Command = $c.Command; Args = $c.Args; Version = $result.Version }
        }
        $script:Diagnostics += "  - '$label' : found Python $($result.Version), but need $RequiredMajor.$RequiredMinor+"
    }

    return Find-PythonInCommonInstallDirs
}

function Update-SessionPath {
    <#
        Re-reads PATH from both machine and user registry scopes and
        merges it into the current session's $env:Path, so a Python
        install that just happened (e.g. via winget) is picked up
        without needing to restart this PowerShell session.
    #>
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

function Install-PythonViaWinget {
    Write-Step "Python $RequiredMajor.$RequiredMinor+ not found on PATH - checking winget"

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Err "winget is not available on this system."
        Write-Host "Install Python $RequiredMajor.$RequiredMinor+ manually from https://www.python.org/downloads/"
        Write-Host "(check 'Add python.exe to PATH' during setup), then re-run this script."
        exit 1
    }

    winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
    $wingetExitCode = $LASTEXITCODE

    # NOTE: a non-zero exit code here does NOT necessarily mean failure.
    # winget returns non-zero for "already installed, nothing to upgrade"
    # (commonly exit code -1978335189 / APPINSTALLER_CLI_ERROR_NO_APPLICABLE_UPDATE)
    # as well as genuine install failures, and it can't be reliably told
    # apart from the exit code alone. So: don't exit here on a non-zero
    # code - just refresh PATH and let the caller re-run Find-Python,
    # which is the only thing that actually tells us whether a usable
    # Python 3.12+ exists now. We only warn if the code suggests trouble.
    if ($wingetExitCode -ne 0) {
        Write-Host "winget exited with code $wingetExitCode - this can mean 'already installed, nothing to upgrade' rather than a real failure. Re-checking for Python directly..." -ForegroundColor Yellow
    }

    Update-SessionPath
    Start-Sleep -Seconds 2
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "== PDF Redactor installer (PowerShell) ==" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"

# Refresh PATH from the registry FIRST, in case Python was installed in an
# earlier session and this terminal window just hasn't picked it up yet -
# this alone resolves the most common "already installed but not found"
# case without ever needing to touch winget.
Update-SessionPath

Write-Step "Locating Python $RequiredMajor.$RequiredMinor+"
$script:Diagnostics = @()

if ($PythonPath) {
    Write-Host "Using explicit -PythonPath: $PythonPath"
    if (-not (Test-Path $PythonPath)) {
        Write-Err "The path given to -PythonPath does not exist: $PythonPath"
        exit 1
    }
    $result = Test-PythonCandidate -Command $PythonPath -ExtraArgs @()
    if (-not $result.Ok) {
        Write-Err "The executable at -PythonPath did not run successfully: $($result.Reason)"
        exit 1
    }
    $parts = $result.Version -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    if ($major -lt $RequiredMajor -or ($major -eq $RequiredMajor -and $minor -lt $RequiredMinor)) {
        Write-Err "The Python at -PythonPath is version $($result.Version), but $RequiredMajor.$RequiredMinor+ is required."
        exit 1
    }
    $python = @{ Command = $PythonPath; Args = @(); Version = $result.Version }
} else {
    $python = Find-Python
}

function Show-PythonNotFoundGuidance {
    param([bool]$AfterWingetAttempt)

    Write-Host ""
    Write-Host "Checked:" -ForegroundColor Yellow
    $script:Diagnostics | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    Write-Host ""

    if ($script:Diagnostics -match 'Microsoft Store') {
        Write-Host "-> 'python'/'python3' on your PATH point to a Microsoft Store" -ForegroundColor Yellow
        Write-Host "   'App execution alias' stub, not your real Python install. Fix:" -ForegroundColor Yellow
        Write-Host "   Settings -> Apps -> Advanced app settings -> App execution aliases" -ForegroundColor Yellow
        Write-Host "   -> turn OFF the switches for 'python.exe' and 'python3.exe'," -ForegroundColor Yellow
        Write-Host "   then open a NEW PowerShell window and run .\install.ps1 again." -ForegroundColor Yellow
        return
    }

    if ($AfterWingetAttempt) {
        Write-Host "If winget reported Python is already installed, it's most likely" -ForegroundColor Yellow
        Write-Host "installed but not visible to THIS terminal session's PATH. Try:" -ForegroundColor Yellow
        Write-Host "  1. Close this PowerShell window completely and open a new one," -ForegroundColor Yellow
        Write-Host "     then run .\install.ps1 again (this refreshes PATH)." -ForegroundColor Yellow
        Write-Host "  2. If that doesn't help, open a new PowerShell window and run:" -ForegroundColor Yellow
    } else {
        Write-Host "To check manually, open a new PowerShell window and run:" -ForegroundColor Yellow
    }
    Write-Host "       py -3.12 --version" -ForegroundColor Yellow
    Write-Host "       Get-Command python,python3,py -All | Format-List Name,Source" -ForegroundColor Yellow
    Write-Host "     and share the output if you need further help." -ForegroundColor Yellow
    Write-Host "     Otherwise install manually from https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "     and check 'Add python.exe to PATH' during setup." -ForegroundColor Yellow
}

if (-not $python) {
    if ($SkipPythonAutoInstall) {
        Write-Err "Python $RequiredMajor.$RequiredMinor+ was not found on PATH, and -SkipPythonAutoInstall was set."
        Show-PythonNotFoundGuidance -AfterWingetAttempt $false
        exit 1
    }
    Install-PythonViaWinget
    $script:Diagnostics = @()
    $python = Find-Python
    if (-not $python) {
        Write-Err "Still could not find a working Python $RequiredMajor.$RequiredMinor+ after checking winget."
        Show-PythonNotFoundGuidance -AfterWingetAttempt $true
        exit 1
    }
}

Write-Ok "Using Python $($python.Version) via '$($python.Command) $($python.Args -join ' ')'"

Write-Step "Creating virtual environment (.\venv)"
if (Test-Path ".\venv\Scripts\python.exe") {
    Write-Ok "Virtual environment already exists - reusing it."
} else {
    & $python.Command @($python.Args + @('-m', 'venv', 'venv'))
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to create virtual environment."
        exit 1
    }
    Write-Ok "Virtual environment created."
}

$venvPython = Join-Path $ProjectRoot 'venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Err "Expected venv Python not found at $venvPython"
    exit 1
}

Write-Step "Installing dependencies from requirements.txt"
& $venvPython -m pip install --upgrade pip --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to upgrade pip."
    exit 1
}

& $venvPython -m pip install -r (Join-Path $ProjectRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) {
    Write-Err "Dependency installation failed. See the pip output above for details."
    exit 1
}

Write-Step "Verifying key dependencies import correctly"
$verifyScript = "import PySide6, fitz, PIL, pytest; print('All key dependencies import OK')"
& $venvPython -c $verifyScript
if ($LASTEXITCODE -ne 0) {
    Write-Err "One or more dependencies failed to import after installation."
    exit 1
}
Write-Ok "Dependency verification passed."

Write-Step "Installation complete"
Write-Host ""
Write-Host "To run PDF Redactor:"
Write-Host "  .\venv\Scripts\python.exe main.py"
Write-Host "  (or activate first: .\venv\Scripts\Activate.ps1  then  python main.py)"
Write-Host ""
Write-Host "If Activate.ps1 is blocked by execution policy, run once:"
Write-Host "  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
Write-Host ""
Write-Host "To run the unit tests:"
Write-Host "  .\venv\Scripts\python.exe -m pytest tests\ -v"
Write-Host ""
Write-Host "To build a standalone executable, see build.bat / build.sh."
