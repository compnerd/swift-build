<#
.SYNOPSIS
Reads a JSON input and generates matrices for the GitHub Actions workflow. This
assumes that some environment variables are set for the various builders and
targets.

.DESCRIPTION
This script reads a JSON input that contains the setup for the matrices. The
script then generates the host, build, and target matrices for the GitHub
Actions workflow. The script assumes that the following environment variables
are set:
    * WINDOWS_X64
    * WINDOWS_X86
    * WINDOWS_ARM64
    * DARWIN_ARM64
    * DARWIN_X64
    * ANDROID_ARM64
    * ANDROID_ARM32
    * ANDROID_X64
    * ANDROID_X86
    * BUILD_WINDOWS_X64
    * BUILD_DARWIN

The script outputs the matrices in JSON format to stdout and also sets the
following GitHub Actions output variables:
    * host_matrix
    * build_matrix
    * target_matrix

.PARAMETER BuildSetup
A JSON string that contains the setup for the matrices. The JSON should be an
object with keys as the builders names and values as an array of target names.

.EXAMPLE
$env:WINDOWS_X64 = '{"os": "Windows", "arch": "amd64"}'
$env:WINDOWS_X86 = '{"os": "Windows", "arch": "x86"}'
$env:WINDOWS_ARM64 = '{"os": "Windows", "arch": "arm64"}'
$env:DARWIN_ARM64 = '{"os": "Darwin", "arch": "arm64"}'
$env:DARWIN_X64 = '{"os": "Darwin", "arch": "x86_64"}'
$env:ANDROID_ARM64 = '{"os": "Android", "arch": "arm64"}'
$env:ANDROID_ARM32 = '{"os": "Android", "arch": "armv7"}'
$env:ANDROID_X64 = '{"os": "Android", "arch": "x86_64"}'
$env:ANDROID_X86 = '{"os": "Android", "arch": "i686"}'
$env:BUILD_WINDOWS_X64 = '{"build_os": "Windows", "build_arch": "amd64"}'
$env:BUILD_DARWIN = '{"build_os": "Darwin", "build_arch": "arm64"}'
./setup-matrix.ps1 -BuildSetup '{
    "Windows-amd64": ["Windows-amd64"],
    "Darwin": ["Darwin"]
}'
Host matrix:
{
  "include": [
    {
      "build_os": "Windows",
      "build_arch": "amd64",
      "os": "Windows",
      "arch": "amd64",
    },
    {
      "build_os": "Darwin",
      "build_arch": "arm64",
      "os": "Darwin",
      "arch": "x86_64",
    },
    {
      "build_os": "Darwin",
      "build_arch": "arm64",
      "os": "Darwin",
      "arch": "arm64",
    }
  ]
}
Build matrix:
{
  "include": [
    {
      "build_os": "Windows",
      "build_arch": "amd64",
      "os": "Windows",
      "arch": "amd64",
    },
    {
      "build_os": "Darwin",
      "build_arch": "arm64",
      "os": "Darwin",
      "arch": "arm64",
    }
  ]
}
Target matrix:
{
  "include": [
    {
      "build_os": "Windows",
      "build_arch": "amd64",
      "os": "Windows",
      "arch": "amd64",
    },
    {
      "build_os": "Windows",
      "build_arch": "amd64",
      "os": "Windows",
      "arch": "x86",
    },
    {
      "build_os": "Darwin",
      "build_arch": "arm64",
      "os": "Darwin",
      "arch": "x86_64",
    },
    {
      "build_os": "Darwin",
      "build_arch": "arm64",
      "os": "Darwin",
      "arch": "arm64",
    }
  ]
}
#>

param (
    [Parameter(Mandatory = $true)]
    [string] $BuildSetup
)

# Get the matrix information from the environment.
$windowsX64 = (Get-Item -Path Env:WINDOWS_X64).Value | ConvertFrom-Json -AsHashtable
$windowsX86 = (Get-Item -Path Env:WINDOWS_X86).Value | ConvertFrom-Json -AsHashtable
$windowsArm64 = (Get-Item -Path Env:WINDOWS_ARM64).Value | ConvertFrom-Json -AsHashtable
$darwinArm64 = (Get-Item -Path Env:DARWIN_ARM64).Value | ConvertFrom-Json -AsHashtable
$darwinX64 = (Get-Item -Path Env:DARWIN_X64).Value | ConvertFrom-Json -AsHashtable
$androidArm64 = (Get-Item -Path Env:ANDROID_ARM64).Value | ConvertFrom-Json -AsHashtable
$androidArm32 = (Get-Item -Path Env:ANDROID_ARM32).Value | ConvertFrom-Json -AsHashtable
$androidX64 = (Get-Item -Path Env:ANDROID_X64).Value | ConvertFrom-Json -AsHashtable
$androidX86 = (Get-Item -Path Env:ANDROID_X86).Value | ConvertFrom-Json -AsHashtable
$buildWindowsX64 = (Get-Item -Path Env:BUILD_WINDOWS_X64).Value | ConvertFrom-Json -AsHashtable
$buildDarwin = (Get-Item -Path Env:BUILD_DARWIN).Value | ConvertFrom-Json -AsHashtable

# Name mapping for targets and builders to variable names.
$targetNameToVarName = @{
    'Darwin' = @('darwinX64', 'darwinArm64')
    'Windows-amd64' = @('windowsX64', 'windowsX86')
    'Windows-arm64' = @('windowsArm64')
    'Android' = @('androidArm64', 'androidArm32', 'androidX64', 'androidX86')
}
$builderNameToVarName = @{
    'Windows-amd64' = 'buildWindowsX64'
    'Darwin' = 'buildDarwin'
}
$hostNameToVarName = @{
    'Windows-amd64' = @('windowsX64')
    'Windows-arm64' = @('windowsArm64')
    'Darwin' = @('darwinArm64', 'darwinX64')
}

# Parse the input JSON.
try {
    $parsedJson = $BuildSetup | ConvertFrom-Json -AsHashtable
} catch {
    Write-Output "::error::Invalid JSON input"
    exit 1
}

# Extract all builder lists.
if ($parsedJson.ContainsKey('Windows-amd64')) {
    $windowsAmd64List = $parsedJson['Windows-amd64']
    if ($windowsAmd64List -isnot [System.Collections.IList]) {
        Write-Output "::error::'Windows-amd64' value is not a list"
        exit 1
    }
} else {
    $windowsAmd64List = @()
}
if ($parsedJson.ContainsKey('Darwin')) {
    $darwinList = $parsedJson['Darwin']
    if ($darwinList -isnot [System.Collections.IList]) {
        Write-Output "::error::'Darwin' value is not a list"
        exit 1
    }
} else {
    $darwinList = @()
}

# Exit early if no builders are found.
if ($windowsAmd64List.Count -eq 0 -and $darwinList.Count -eq 0) {
    Write-Output "::error::No builders found in the input"
    exit 1
}

# Build the target to builder mapping.
$targetToBuilder = @{}
foreach ($target in $windowsAmd64List) {
    if (-not $targetNameToVarName.ContainsKey($target)) {
        Write-Output "::error::Invalid target found: $target"
        exit 1
    }
    if ($targetToBuilder.ContainsKey($target)) {
        Write-Output "::error::Duplicate builders found for target $target"
        exit 1
    }
    $targetToBuilder[$target] = 'Windows-amd64'
}
foreach ($target in $darwinList) {
    if (-not $targetNameToVarName.ContainsKey($target)) {
        Write-Output "::error::Invalid target found: $target"
        exit 1
    }
    if ($targetToBuilder.ContainsKey($target)) {
        Write-Output "::error::Duplicate builders found for target $target"
        exit 1
    }
    $targetToBuilder[$target] = 'Darwin'
}

# Populate the builder information.
foreach ($kvp in $targetToBuilder.GetEnumerator()) {
    $target = $kvp.Key
    $builder = $kvp.Value

    # Get the builder information for this target.
    $builderVarName = $builderNameToVarName[$builder]
    $builderVar = Get-Variable -Name $builderVarName -ValueOnly

    # Append the builder information for these bots.
    foreach($targetVarName in $targetNameToVarName[$target]) {
        $targetVar = Get-Variable -Name $targetVarName
        $targetVar.Value += $builderVar
    }
}

# Build the host matrix.
$hostMatrix = @()
foreach ($kvp in $hostNameToVarName.GetEnumerator()) {
    $hostName = $kvp.Key
    if (-not $targetToBuilder.ContainsKey($hostName)) {
        Write-Host "Skipping host $hostName" -ForegroundColor Yellow
        continue
    }
    foreach ($hostVarName in $kvp.Value) {
        $hostMatrix += (Get-Variable -Name $hostVarName -ValueOnly)
    }
}

# Build the build matrix.
$buildMatrix = @()
if ($windowsAmd64List.Count -gt 0) {
    $buildMatrix += $windowsX64
}
if ($darwinList.Count -gt 0) {
    $buildMatrix += $darwinArm64
}

# Build the target matrix.
$targetMatrix = @()
foreach ($target in $windowsAmd64List + $darwinList) {
    foreach ($targetVarName in $targetNameToVarName[$target]) {
        $targetDict = Get-Variable -Name $targetVarName -ValueOnly
        $targetMatrix += $targetDict
    }
}

$hostMatrix = @{ 'include' = $hostMatrix }
$buildMatrix = @{ 'include' = $buildMatrix }
$targetMatrix = @{ 'include' = $targetMatrix }

# Output the matrix.
Write-Host "Host matrix:"
Write-Host $($hostMatrix | ConvertTo-Json)
Write-Host "Build matrix:"
Write-Host $($buildMatrix | ConvertTo-Json)
Write-Host "Target matrix:"
Write-Host $($targetMatrix | ConvertTo-Json)

Write-Output host_matrix=$($hostMatrix | ConvertTo-Json -Compress )| Out-File -FilePath ${env:GITHUB_OUTPUT} -Encoding utf8 -Append
Write-Output build_matrix=$($buildMatrix | ConvertTo-Json -Compress ) | Out-File -FilePath ${env:GITHUB_OUTPUT} -Encoding utf8 -Append
Write-Output target_matrix=$($targetMatrix | ConvertTo-Json -Compress ) | Out-File -FilePath ${env:GITHUB_OUTPUT} -Encoding utf8 -Append
