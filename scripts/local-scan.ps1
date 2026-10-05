<#
.SYNOPSIS
    Runs the QuantumSecurity scans against a project on your own machine.

.DESCRIPTION
    Uses the same scanners, versions, and rules as the CI workflow. Each scanner runs
    from its official Docker image, so the only thing you need installed is Docker.
    The project folder is mounted read-only, so the scans cannot change it.

.EXAMPLE
    .\scripts\local-scan.ps1 -Project C:\QuantumLogicsLabs\QuantumChat

.EXAMPLE
    .\scripts\local-scan.ps1 -Project ..\QuantumChat -Scan secrets, code
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [ValidateSet('secrets', 'dependencies', 'code')]
    [string[]]$Scan = @('secrets', 'dependencies', 'code')
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker was not found. Install Docker Desktop, start it, and run this script again.'
}

$projectPath = (Resolve-Path -LiteralPath $Project).Path
$securityPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

# Keep these versions in step with scripts/install-tools.sh.
$images = @{
    secrets      = 'ghcr.io/gitleaks/gitleaks:v8.30.1'
    dependencies = 'ghcr.io/google/osv-scanner:v2.6.0'
    code         = 'semgrep/semgrep:1.179.0'
}

# A git repository is scanned through its whole history; a plain folder is scanned as files.
$gitleaksMode = 'dir'
if (Test-Path -LiteralPath (Join-Path $projectPath '.git')) { $gitleaksMode = 'git' }

$commands = @{
    secrets      = @($gitleaksMode, '.', '--config', '/quantum-security/configs/gitleaks.toml',
                     '--redact', '--verbose', '--no-banner')
    dependencies = @('scan', 'source', '--recursive', '.')
    code         = @('semgrep', 'scan', '--config', 'p/default', '--config', 'p/owasp-top-ten',
                     '--config', '/quantum-security/configs/semgrep/rules', '--metrics', 'off', '--error', '.')
}

# The mounted folder belongs to a different user than the one inside the container,
# so git has to be told that it is safe to read.
$dockerArgs = @(
    'run', '--rm',
    '-e', 'GIT_CONFIG_COUNT=1', '-e', 'GIT_CONFIG_KEY_0=safe.directory', '-e', 'GIT_CONFIG_VALUE_0=*',
    '-v', "${projectPath}:/project:ro",
    '-v', "${securityPath}:/quantum-security:ro",
    '-w', '/project'
)

$flagged = @()
foreach ($name in $Scan) {
    Write-Host ''
    Write-Host "=== $name ===" -ForegroundColor Cyan
    $runArgs = $dockerArgs + @($images[$name]) + $commands[$name]
    & docker @runArgs
    $code = $LASTEXITCODE
    # OSV-Scanner exits with 128 when the project has no lockfiles, which is not a finding.
    $clean = ($code -eq 0) -or ($name -eq 'dependencies' -and $code -eq 128)
    if (-not $clean) { $flagged += $name }
}

Write-Host ''
if ($flagged.Count -gt 0) {
    Write-Host "Findings or errors in: $($flagged -join ', ')" -ForegroundColor Yellow
    exit 1
}
Write-Host 'All scans passed.' -ForegroundColor Green
exit 0
