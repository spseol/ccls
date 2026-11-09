<#
.SYNOPSIS
  Builds ccls for Windows and packages it (portable zip + NSIS installer).

.DESCRIPTION
  Uses an MSYS2 UCRT64 toolchain (gcc + LLVM/Clang dev libraries). The result
  is relocatable: bin\ccls.exe, the runtime DLLs it needs and the Clang
  resource directory (lib\clang\<N>\include) are packaged together, so the
  package installs on a clean Windows 10/11 without MSYS2 or LLVM.

  Outputs (in -OutDir, default <repo>\dist):
    ccls-<version>-windows-x64.zip
    ccls-<version>-windows-x64-setup.exe

.PARAMETER Version       Release version; default `git describe --tags --always`.
.PARAMETER Msys2Root     MSYS2 location (default C:\msys64).
.PARAMETER InstallDeps   Install/update the required MSYS2 packages first.
.PARAMETER SkipInstaller Build only the zip.
.PARAMETER Clean         Remove the build directory first.
.PARAMETER Jobs          Parallel build jobs (default: number of CPUs).

.EXAMPLE
  .\windows\build-release.ps1 -InstallDeps
  .\windows\build-release.ps1 -Version 0.20261104 -Clean
#>
[CmdletBinding()]
param(
  [string]$Version,
  [string]$Msys2Root = 'C:\msys64',
  [string]$BuildDir,
  [string]$OutDir,
  [switch]$InstallDeps,
  [switch]$SkipInstaller,
  [switch]$Clean,
  [int]$Jobs = [Environment]::ProcessorCount
)
$ErrorActionPreference = 'Stop'

$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $BuildDir) { $BuildDir = Join-Path $Repo 'build-windows' }
if (-not $OutDir)   { $OutDir   = Join-Path $Repo 'dist' }
if (-not $Version) {
  $Version = (git -C $Repo describe --tags --always 2>$null)
  if (-not $Version) { $Version = 'dev' }
}
$Version = $Version.Trim() -replace '[^0-9A-Za-z._-]', '_'
$Name = "ccls-$Version-windows-x64"

$Bash = Join-Path $Msys2Root 'usr\bin\bash.exe'
if (-not (Test-Path $Bash)) {
  throw "MSYS2 not found at $Msys2Root. Install it from https://www.msys2.org/ (or pass -Msys2Root)."
}

# Run a bash snippet inside the MSYS2 UCRT64 environment.
function Invoke-Msys([string]$Script) {
  $env:MSYSTEM = 'UCRT64'
  $env:CHERE_INVOKING = '1'
  # Pass the script as a file: multi-line/quoted -c arguments get mangled by
  # Windows command-line quoting.
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ccls-build-" + [guid]::NewGuid().ToString('N') + '.sh')
  [IO.File]::WriteAllText($tmp, ($Script -replace "`r", ''), (New-Object Text.UTF8Encoding($false)))
  try {
    & $Bash -l $tmp
    if ($LASTEXITCODE -ne 0) { throw "MSYS2 command failed (exit $LASTEXITCODE)" }
  } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

$pkgList = ('clang', 'clang-tools-extra', 'llvm', 'cmake', 'ninja', 'rapidjson', 'nsis' | ForEach-Object { "mingw-w64-ucrt-x86_64-$_" }) -join ' '
if ($InstallDeps) {
  Write-Host '==> Installing MSYS2 packages' -ForegroundColor Cyan
  Invoke-Msys "pacman -Sy --noconfirm && pacman -S --needed --noconfirm $pkgList"
}

if ($Clean -and (Test-Path $BuildDir)) { Remove-Item -Recurse -Force $BuildDir }
$Stage = Join-Path $OutDir $Name
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
New-Item -ItemType Directory -Force $OutDir, $Stage | Out-Null

$env:CCLS_REPO  = $Repo
$env:CCLS_BUILD = $BuildDir
$env:CCLS_STAGE = $Stage
$env:CCLS_JOBS  = $Jobs

Write-Host '==> Configuring and building' -ForegroundColor Cyan
Invoke-Msys @'
set -e
repo=$(cygpath -u "$CCLS_REPO"); build=$(cygpath -u "$CCLS_BUILD"); stage=$(cygpath -u "$CCLS_STAGE")
cmake -S "$repo" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$stage" \
  -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
  -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc
cmake --build "$build" -j "$CCLS_JOBS"
cmake --install "$build" --prefix "$stage" --strip

# Runtime DLLs (everything ldd resolves inside the MSYS2 prefix).
ldd "$stage/bin/ccls.exe" | awk '/=>/ {print $3}' | grep -i '/ucrt64/' | sort -u | while read -r dll; do
  cp -v "$dll" "$stage/bin/"
done

# Clang resource directory (builtin headers).
res=$(clang -print-resource-dir)
major=$(basename "$res")
mkdir -p "$stage/lib/clang/$major"
cp -r "$res/include" "$stage/lib/clang/$major/"
'@

# Smoke test the staged binary with MSYS2 removed from PATH.
Write-Host '==> Smoke test' -ForegroundColor Cyan
$savedPath = $env:PATH
$env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
try {
  $out = & (Join-Path $Stage 'bin\ccls.exe') --version 2>&1
  if ($LASTEXITCODE -ne 0) { throw "ccls.exe --version failed: $out" }
  Write-Host ($out | Out-String)
} finally { $env:PATH = $savedPath }

Copy-Item (Join-Path $Repo 'LICENSE') $Stage
Copy-Item (Join-Path $PSScriptRoot 'README-windows.txt') $Stage

Write-Host '==> Creating zip' -ForegroundColor Cyan
$Zip = Join-Path $OutDir "$Name.zip"
if (Test-Path $Zip) { Remove-Item $Zip }
Compress-Archive -Path $Stage -DestinationPath $Zip -CompressionLevel Optimal

if (-not $SkipInstaller) {
  Write-Host '==> Creating installer' -ForegroundColor Cyan
  $Setup = Join-Path $OutDir "$Name-setup.exe"
  $makensis = Join-Path $Msys2Root 'ucrt64\bin\makensis.exe'
  if (-not (Test-Path $makensis)) { throw 'makensis not found; run with -InstallDeps' }
  & $makensis /V2 "/DVERSION=$Version" "/DSRCDIR=$Stage" "/DOUTFILE=$Setup" (Join-Path $PSScriptRoot 'ccls.nsi')
  if ($LASTEXITCODE -ne 0) { throw 'makensis failed' }
}

Write-Host "==> Done. Artifacts in $OutDir" -ForegroundColor Green
Get-ChildItem $OutDir -File | ForEach-Object { '{0,10:N1} MB  {1}' -f ($_.Length / 1MB), $_.Name }
