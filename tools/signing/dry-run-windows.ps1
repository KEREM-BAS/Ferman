# The code-signing dry run on Windows (ROADMAP §8 exit check, risk "Code signing and
# notarization"): signs a copy of a built Release folder as M5's release will, every .exe and
# .dll with SHA-256 Authenticode, PDFium included, but with a throwaway self-signed certificate,
# then verifies each signature. No secrets, no timestamp server; the original folder is not
# touched. tools/signing/README.md says what M5 adds.
#
# Usage: pwsh tools/signing/dry-run-windows.ps1 <Release folder>
# Needs an elevated shell (a CI runner): the certificate is trusted in LocalMachine\Root for the
# verification and removed again at the end.
param([Parameter(Mandatory = $true)][string]$Release)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path (Join-Path $Release 'ferman.exe'))) {
  Write-Error "No ferman.exe in $Release"
}
$signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" |
  Sort-Object FullName | Select-Object -Last 1
if (-not $signtool) { Write-Error 'signtool.exe not found in the Windows SDK' }

$work = Join-Path ([System.IO.Path]::GetTempPath()) "ferman-signing-$PID"
$copy = Join-Path $work 'Release'
New-Item -ItemType Directory -Path $work | Out-Null
Copy-Item -Recurse $Release $copy
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=Ferman Signing Dry Run' `
  -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddDays(1)
$public = Join-Path $work 'dry-run.cer'
Export-Certificate -Cert $cert -FilePath $public | Out-Null
$root = Import-Certificate -FilePath $public -CertStoreLocation Cert:\LocalMachine\Root
try {
  $files = Get-ChildItem $copy -Recurse -Include *.exe, *.dll
  if ($files.Count -lt 3) { throw "Only $($files.Count) binaries in $Release" }
  foreach ($file in $files) {
    & $signtool.FullName sign /fd SHA256 /sha1 $cert.Thumbprint /s My $file.FullName
    if ($LASTEXITCODE -ne 0) { throw "signtool sign failed on $($file.Name)" }
    & $signtool.FullName verify /pa /q $file.FullName
    if ($LASTEXITCODE -ne 0) { throw "signtool verify failed on $($file.Name)" }
  }
  if (-not ($files.Name -contains 'ferman-mcp.exe')) { throw 'ferman-mcp.exe is missing' }
  Write-Output "Signed and verified $($files.Count) binaries with a throwaway certificate."
} finally {
  Remove-Item -Path "Cert:\LocalMachine\Root\$($root.Thumbprint)"
  Remove-Item -Path "Cert:\CurrentUser\My\$($cert.Thumbprint)" -DeleteKey
  Remove-Item -Recurse -Force $work
}
