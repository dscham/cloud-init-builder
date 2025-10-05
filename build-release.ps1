<#
.SYNOPSIS
    Cross-compiles a Go application for various common platforms and architectures.

.DESCRIPTION
    This script iterates through a defined list of GOOS/GOARCH combinations
    (Linux, Windows, Darwin/macOS) and executes 'go build' for each target.
    The resulting binaries are placed in the 'release/' directory with standard
    naming conventions (e.g., 'myapp_linux_amd64').

.PARAMETER BinaryName
    The desired name for the final executable. Defaults to the current directory's name.

.PARAMETER PackagePath
    The path to the package containing the main function to build.
    This can be a directory (e.g., './cmd/mycli') or a path to a main Go file.
    Defaults to the current directory ('.').
#>
# Script-level parameter block. This must be the first executable statement in the file.
param(
    [string]$BinaryName,
    [string]$PackagePath
)

# Set the strict mode to catch errors early. This now comes AFTER the param block.
Set-StrictMode -Version Latest

# --- Robust Default Calculation ---
# If the user did not specify the BinaryName, calculate the default from the current directory name.
if ([string]::IsNullOrEmpty($BinaryName)) {
    $BinaryName = Split-Path -Path (Get-Location) -Leaf
    Write-Host "No BinaryName provided. Defaulting to '$BinaryName'." -ForegroundColor Gray
}

# If the user did not specify the PackagePath, default to the current directory.
if ([string]::IsNullOrEmpty($PackagePath)) {
    $PackagePath = "."
    Write-Host "No PackagePath provided. Defaulting to '$PackagePath'." -ForegroundColor Gray
}
# ------------------------------------

# Resolve the PackagePath to an absolute path for consistency.
try {
    $ResolvedPackagePath = Resolve-Path -Path $PackagePath -ErrorAction Stop
}
catch {
    Write-Host "ERROR: The specified PackagePath '$PackagePath' could not be resolved. Aborting." -ForegroundColor Red
    # Exit the script if the path is invalid.
    exit 1
}

# --- Configuration ---
$OutputDir = "release"
# Define the GOOS and GOARCH combinations for compilation
$Targets = @(
    @{ GOOS = "windows"; GOARCH = "amd64" },
    @{ GOOS = "linux";   GOARCH = "amd64" },
    @{ GOOS = "darwin";  GOARCH = "amd64" }, # macOS Intel
    @{ GOOS = "darwin";  GOARCH = "arm64" }  # macOS Apple Silicon (M-series)
)
# ---------------------

Write-Host "`n--- Go Cross-Compiler Started ---" -ForegroundColor Cyan
Write-Host "Target Binary Name: $BinaryName" -ForegroundColor Yellow
Write-Host "Go Package Path: $ResolvedPackagePath" -ForegroundColor Yellow

# 1. Clean up and prepare the output directory
if (Test-Path -Path $OutputDir -PathType Container) {
    Remove-Item -Path $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed existing '$OutputDir' directory." -ForegroundColor DarkYellow
}
New-Item -Path $OutputDir -ItemType Directory | Out-Null
Write-Host "Created new '$OutputDir' directory." -ForegroundColor DarkGreen

# 2. Iterate through targets and build
foreach ($Target in $Targets) {
    $os = $Target.GOOS
    $arch = $Target.GOARCH

    # Determine file extension (Windows only uses .exe)
    $ext = if ($os -eq "windows") { ".exe" } else { "" }

    # Construct the final output file path and name
    $OutputFile = Join-Path -Path $OutputDir -ChildPath "$($BinaryName)_$($os)_$($arch)$ext"

    Write-Host "`nBuilding for $os/$arch..." -ForegroundColor Yellow

    try {
        # Execute the build command within a script block (& { ... }) to ensure GOOS/GOARCH are
        # correctly set as environment variables for the external 'go build' process only.
        # This method is compatible with older PowerShell versions.
        & {
            $env:GOOS = $os
            $env:GOARCH = $arch
            $env:CGO_ENABLED = 0

            # Execute go build with the resolved package path and output file
            go build -o $OutputFile -ldflags "-s -w" $ResolvedPackagePath
        }

        if ($LASTEXITCODE -ne 0) {
            # If 'go build' returns a non-zero exit code, throw an error
            throw "Go build failed for $os/$arch (Exit Code: $LASTEXITCODE). Please check Go toolchain output."
        }

        Write-Host "-> Successfully built: $OutputFile" -ForegroundColor Green
    }
    catch {
        Write-Host "-> ERROR: Build failed for $os/$arch. $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n--- Cross-Compilation Complete ---" -ForegroundColor Cyan
Write-Host "All resulting binaries are available in the '$OutputDir' directory."

