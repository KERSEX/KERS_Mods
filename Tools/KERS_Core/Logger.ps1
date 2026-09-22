# =====================================================================
#  KERS Core - Logger
#  Log-Level: DEBUG < INFO < WARN < ERROR
#  Logs liegen unter %LOCALAPPDATA%\KERS_Mods\logs\<Name>.log
# =====================================================================

$script:KersLogLevels = @{ DEBUG = 0; INFO = 1; WARN = 2; ERROR = 3 }
$script:KersLogFile   = $null
$script:KersLogMin    = 1

function Get-KersDataDir {
    $d = $env:LOCALAPPDATA
    if (-not $d) { $d = $env:TEMP }
    if (-not $d) { $d = (Get-Location).Path }
    return (Join-Path $d 'KERS_Mods')
}

function Initialize-KersLog {
    param(
        [string]$Name = 'KERS',
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $script:KersLogMin = $script:KersLogLevels[$Level]
    try {
        $dir = Join-Path (Get-KersDataDir) 'logs'
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $file = Join-Path $dir ($Name + '.log')
        # ab 1 MB eine Generation zurueckrollen
        if (Test-Path -LiteralPath $file) {
            $size = (Get-Item -LiteralPath $file).Length
            if ($size -gt 1MB) {
                Move-Item -LiteralPath $file -Destination ($file + '.1') -Force
            }
        }
        $script:KersLogFile = $file
        Write-KersLog ('--- Start ' + $Name + ' (PowerShell ' + $PSVersionTable.PSVersion + ') ---') 'DEBUG'
    } catch {
        $script:KersLogFile = $null
    }
    return $script:KersLogFile
}

function Write-KersLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    if ($script:KersLogLevels[$Level] -lt $script:KersLogMin) { return }
    if (-not $script:KersLogFile) { return }
    try {
        $line = '{0} [{1,-5}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Add-Content -LiteralPath $script:KersLogFile -Value $line -Encoding UTF8
    } catch { }
}

function Get-KersLogFile { return $script:KersLogFile }
