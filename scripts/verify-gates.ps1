$ErrorActionPreference = "Continue"
$Repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Write-Output "==== G0 ===="
$goMod = Test-Path "$Repo\core\src\foss\golang\clash\go.mod"
$hdc = Get-Command hdc -ErrorAction SilentlyContinue
$sdk = Test-Path "D:\software\harmonyos\command-line-tools\sdk"
$go = Test-Path "D:\software\go\bin\go.exe"
Write-Output "mihomo_go.mod=$goMod sdk=$sdk go=$go hdc=$($null -ne $hdc)"
if ($hdc) { hdc list targets }
Write-Output "==== G1 artifact ===="
Get-ChildItem "$Repo\harmony\entry\build" -Recurse -Filter "*.hap" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
Write-Output "==== G3 so ===="
Get-Item "$Repo\harmony\entry\libs\arm64-v8a\libclash.so" -ErrorAction SilentlyContinue | Format-List FullName, Length
Write-Output "DONE"
