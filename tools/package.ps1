<#
.SYNOPSIS
  Packages a Bedrock add-on repo into an importable .mcaddon file.

.DESCRIPTION
  Finds every pack in the repo (any folder with a manifest.json), then builds
  <Name>-<version>.mcaddon with all of them. The name and version come from
  the behavior pack's manifest, e.g. "Snowfall [1.1.0]" -> Snowfall-1.1.0.mcaddon.

  Works on any add-on repo, not just Snowfall:

    # This repo, into .\dist
    powershell -ExecutionPolicy Bypass -File tools\package.ps1

    # Another repo, into a shared folder
    powershell -ExecutionPolicy Bypass -File tools\package.ps1 -Repo ..\stronger-skeletons -OutDir ..\builds

  Double-clicking a built file imports it into Minecraft. Importing an
  .mcaddon only adds the packs to the library; each world still chooses which
  packs to turn on.

.PARAMETER Repo
  The add-on repo to package. Defaults to the repo this script is in.

.PARAMETER OutDir
  Where to write the files. Defaults to <Repo>\dist. A file with the same name
  is replaced; other files in the folder are left alone.

.PARAMETER PerPack
  Also build a separate .mcpack for each pack (e.g. Thaw on its own).
#>
param(
  [string]$Repo = (Split-Path $PSScriptRoot -Parent),
  [string]$OutDir,
  [switch]$PerPack
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Repo = (Resolve-Path $Repo).Path
if (-not $OutDir) { $OutDir = Join-Path $Repo "dist" }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

# --- Find the packs --------------------------------------------------------

$skip = '\\(\.git|\.vs|\.vscode|node_modules|dist)(\\|$)'
$packs = Get-ChildItem $Repo -Recurse -Filter "manifest.json" -File |
  Where-Object { $_.DirectoryName -notmatch $skip } |
  ForEach-Object {
    [pscustomobject]@{
      Dir      = $_.DirectoryName
      Manifest = Get-Content $_.FullName -Raw | ConvertFrom-Json
    }
  }
if (-not $packs) { throw "No packs (folders with manifest.json) found in $Repo." }

# Use the behavior pack (data/script module) for the add-on's name and version.
$main = $packs | Where-Object { $_.Manifest.modules.type -contains "data" -or $_.Manifest.modules.type -contains "script" } |
  Select-Object -First 1
if (-not $main) { $main = $packs | Select-Object -First 1 }

function Get-CleanName([string]$name) {
  $name = $name -replace '§.', ''            # color/format codes like §b§l
  $name = $name -replace '\[[^\]]*\]', ''    # version tags like [1.0.2]
  $name = ($name.Trim() -replace '[\\/:*?"<>|]', '') -replace '\s+', '-'
  return $name
}

$name    = Get-CleanName $main.Manifest.header.name
$version = $main.Manifest.header.version -join "."

# --- Zip helper -------------------------------------------------------------

# Builds the zip with .NET directly instead of Compress-Archive: Windows
# PowerShell's Compress-Archive writes backslashes in entry names, which can
# break imports on Android, iOS and console. Zip entries must use "/".
function New-PackArchive {
  param(
    [hashtable]$Sources,  # folder name inside the zip ("" = zip root) -> folder on disk
    [string]$OutName
  )
  $final = Join-Path $OutDir $OutName
  if (Test-Path $final) { Remove-Item $final }
  $zip = [IO.Compression.ZipFile]::Open($final, "Create")
  try {
    foreach ($prefix in $Sources.Keys) {
      $folder = $Sources[$prefix]
      foreach ($file in Get-ChildItem $folder -Recurse -File) {
        $relative = $file.FullName.Substring($folder.Length + 1) -replace "\\", "/"
        $entry = if ($prefix) { "$prefix/$relative" } else { $relative }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry) | Out-Null
      }
    }
  } finally {
    $zip.Dispose()
  }
  Write-Host ("  {0}  ({1} KB)" -f $OutName, [math]::Round((Get-Item $final).Length / 1KB))
}

# --- Build ------------------------------------------------------------------

Write-Host "Packaging $name $version ($($packs.Count) packs) into $OutDir"

# .mcaddon: each pack FOLDER sits at the root of the zip.
$all = @{}
foreach ($p in $packs) { $all[(Split-Path $p.Dir -Leaf)] = $p.Dir }
New-PackArchive -Sources $all -OutName "$name-$version.mcaddon"

# .mcpack: the pack's CONTENTS sit at the root of the zip (manifest.json at top level).
if ($PerPack) {
  foreach ($p in $packs) {
    $packName = Get-CleanName $p.Manifest.header.name
    $packVersion = $p.Manifest.header.version -join "."
    $kind = if ($p.Manifest.modules.type -contains "resources") { "RP" } else { "BP" }
    New-PackArchive -Sources @{ "" = $p.Dir } -OutName "$packName-$kind-$packVersion.mcpack"
  }
}
