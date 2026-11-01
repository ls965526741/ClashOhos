$ErrorActionPreference = "Stop"
$Repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if ([string]::IsNullOrEmpty($env:GOPROXY)) {
  $env:GOPROXY = "https://goproxy.cn,direct"
}
$Llvm = "D:\software\harmonyos\command-line-tools\sdk\default\openharmony\native\llvm"
$Sysroot = "D:\software\harmonyos\command-line-tools\sdk\default\openharmony\native\sysroot"
$StockGo = "D:\software\go\bin\go.exe"
$OhosGo = "D:\software\ohos_golang_go\bin\go.exe"
if (-not (Test-Path $OhosGo)) { throw "ohos-go missing: $OhosGo" }
if (-not (Test-Path $StockGo)) { $StockGo = "go" }
$Native = Join-Path $Repo "core\src\main\golang"
$ClangExe = Join-Path $Llvm "bin\clang.exe"
$ArExe = Join-Path $Llvm "bin\llvm-ar.exe"
$ArCmd = Join-Path $env:TEMP "ar.cmd"
@"
@echo off
"$ArExe" %*
"@ | Set-Content -Path $ArCmd -Encoding ASCII
$env:PATH = "$env:TEMP;" + $env:PATH
$env:AR = $ArExe
$env:CGO_ENABLED = "1"
$env:GOTOOLCHAIN = "local"
$env:CGO_CFLAGS = "-D__OHOS__ -D__MUSL__ -fPIC -ftls-model=global-dynamic"
$env:CGO_LDFLAGS = "-lhilog_ndk.z"

function Build-ClashArchive {
  param(
    [string]$GoBin,
    [string]$GoRoot,
    [string]$GoOs,
    [string]$GoArch,
    [string]$Triple,
    [string]$AbiDir
  )
  $outDir = Join-Path $Repo "harmony\entry\src\main\cpp\prebuilt\$AbiDir"
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $libDir = Join-Path $Sysroot "usr\lib\$Triple"
  $ccCmd = Join-Path $env:TEMP "ohos-$GoArch-cc.cmd"
  @"
@echo off
"$ClangExe" -target $Triple --sysroot="$Sysroot" -D__MUSL__ -D__OHOS__ -fPIC -ftls-model=global-dynamic -Wno-unused-command-line-argument -L"$libDir" %*
"@ | Set-Content -Path $ccCmd -Encoding ASCII
  $env:GOROOT = $GoRoot
  $env:GOOS = $GoOs
  $env:GOARCH = $GoArch
  $env:CC = $ccCmd
  Write-Output "Building GOOS=$GoOs GOARCH=$GoArch GOROOT=$GoRoot"
  Push-Location $Native
  try {
    $outA = Join-Path $outDir "libclash.a"
    & $GoBin build -buildmode=c-archive -tags "foss with_gvisor cmfa ohos" -trimpath -o $outA ./native
    if ($LASTEXITCODE -ne 0) { throw "go build failed for $GoArch" }
    Get-Item $outA | Format-List Name, Length, FullName
  } finally {
    Pop-Location
  }
}

& $OhosGo version
Build-ClashArchive -GoBin $OhosGo -GoRoot "D:\software\ohos_golang_go" -GoOs "openharmony" -GoArch "arm64" -Triple "aarch64-linux-ohos" -AbiDir "arm64-v8a"
Build-ClashArchive -GoBin $StockGo -GoRoot "D:\software\go" -GoOs "linux" -GoArch "amd64" -Triple "x86_64-linux-ohos" -AbiDir "x86_64"

Get-ChildItem (Join-Path $Repo "harmony\entry\libs") -Recurse -Filter "libclash.so*" -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Output "c-archive arm64(openharmony) + x86_64(linux) ready"
