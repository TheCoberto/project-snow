<#
.SYNOPSIS
  Rebuilds Snowfall's biome overrides from Mojang's vanilla biome files.

.DESCRIPTION
  For every biome in $Biomes below, this downloads the vanilla definition from
  Mojang/bedrock-samples, replaces ONLY its "minecraft:climate" block with a
  winter climate, and adds a "snowfall" tag (Snowfall Thaw uses that tag to
  tell that Snowfall is still turned on). Everything else stays vanilla, so
  terrain, villages, mobs and structures are untouched.

  It also writes the Thaw pack's biome list, so both packs always agree on
  which biomes Snowfall changed.

  Run it after a Minecraft update so the overrides match the new vanilla files:

    powershell -ExecutionPolicy Bypass -File tools\update-biomes.ps1

.PARAMETER Ref
  Branch or tag of Mojang/bedrock-samples to copy from. "main" is the latest
  full release; a tag such as "v1.26.60.5" pins a specific game version.
#>
param(
  [string]$Ref = "main"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Snow only falls where temperature is below 0.15 AND downfall is above 0.
# Values are strings so they are written exactly as typed, whatever the PC's locale.
$Default = @{ Temperature = "0.0"; Downfall = "0.9"; Accumulation = "0.0, 0.125" }

# Biome file name -> climate. An empty @{} uses $Default.
# To add or remove a biome, edit this list and rerun the script.
$Biomes = [ordered]@{
  # Plains get the coldest weather and the deepest snow.
  "plains"                           = @{ Temperature = "-2.0"; Downfall = "1.0"; Accumulation = "0.125, 0.5" }
  "sunflower_plains"                 = @{}
  "meadow"                           = @{}
  "cherry_grove"                     = @{}

  "forest"                           = @{}
  "forest_hills"                     = @{}
  "flower_forest"                    = @{}
  "dappled_forest"                   = @{}
  "birch_forest"                     = @{}
  "birch_forest_hills"               = @{}
  "birch_forest_mutated"             = @{}
  "birch_forest_hills_mutated"       = @{}
  "roofed_forest"                    = @{}
  "roofed_forest_mutated"            = @{}
  "pale_garden"                      = @{}

  "taiga"                            = @{}
  "taiga_hills"                      = @{}
  "taiga_mutated"                    = @{}
  "mega_taiga"                       = @{}
  "mega_taiga_hills"                 = @{}
  "redwood_taiga_mutated"            = @{}
  "redwood_taiga_hills_mutated"      = @{}

  "extreme_hills"                    = @{}
  "extreme_hills_edge"               = @{}
  "extreme_hills_mutated"            = @{}
  "extreme_hills_plus_trees"         = @{}
  "extreme_hills_plus_trees_mutated" = @{}

  "swampland"                        = @{}
  "swampland_mutated"                = @{}
  "mangrove_swamp"                   = @{}

  # Water edges, so there's no strip of rain between snowy land and the sea.
  # Rivers will freeze over.
  "river"                            = @{}
  "beach"                            = @{}
  "stone_beach"                      = @{}
}

$SnowfallTag = "snowfall"

$repoRoot = Split-Path $PSScriptRoot -Parent
$packsDir = Join-Path $repoRoot "TheCoberto's Snowfall"
$biomeDir = Join-Path $packsDir "Snowfall BP\biomes"
$thawList = Join-Path $packsDir "Snowfall Thaw BP\scripts\biomes.js"
$baseUrl  = "https://raw.githubusercontent.com/Mojang/bedrock-samples/$Ref/behavior_pack/biomes"
$utf8     = New-Object System.Text.UTF8Encoding $false   # no BOM

$climateRe = [regex]'"minecraft:climate"\s*:\s*\{[^{}]*\}'
$tagsRe    = [regex]'("minecraft:tags"\s*:\s*\{\s*"tags"\s*:\s*\[)(\s*)'
$idRe      = [regex]'"identifier"\s*:\s*"([^"]+)"'

# Download and transform everything first, so a failure leaves the pack untouched.
$outputs = [ordered]@{}
$ids = @()
foreach ($name in $Biomes.Keys) {
  $climate = $Default.Clone()
  foreach ($k in $Biomes[$name].Keys) { $climate[$k] = $Biomes[$name][$k] }

  $file = "$name.biome.json"
  Write-Host "  $file"
  $json = (Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/$file").Content
  if ($json -is [byte[]]) { $json = $utf8.GetString($json) }

  if ($climateRe.Matches($json).Count -ne 1) { throw "$file has no single minecraft:climate block to replace." }
  if ($tagsRe.Matches($json).Count -ne 1)    { throw "$file has no minecraft:tags list to add the snowfall tag to." }

  $newClimate = @"
"minecraft:climate": {
        "downfall": $($climate.Downfall),
        "snow_accumulation": [ $($climate.Accumulation) ],
        "temperature": $($climate.Temperature)
      }
"@ -replace "`r", ""

  $json = $climateRe.Replace($json, $newClimate, 1)
  $json = $tagsRe.Replace($json, "`$1`$2`"$SnowfallTag`",`$2", 1)

  $outputs[$file] = $json
  $ids += $idRe.Match($json).Groups[1].Value
}

# Replace the biome folder's contents with the fresh files.
Get-ChildItem -Path $biomeDir -Filter "*.biome.json" | Remove-Item
foreach ($file in $outputs.Keys) {
  [IO.File]::WriteAllText((Join-Path $biomeDir $file), $outputs[$file], $utf8)
}

# Write the Thaw pack's copy of the biome list.
$lines = @(
  "// Generated by tools/update-biomes.ps1. Edit the biome list there, not here.",
  "// These are the biomes Snowfall turns wintry, so Thaw only melts snow and ice in them.",
  "export const SNOWFALL_BIOMES = new Set(["
) + ($ids | ForEach-Object { "  `"$_`"," }) + @(
  "]);",
  "",
  "// Tag that Snowfall adds to every biome it changes. If a biome still has it, Snowfall is on.",
  "export const SNOWFALL_TAG = `"$SnowfallTag`";",
  ""
)
[IO.File]::WriteAllText($thawList, ($lines -join "`n"), $utf8)

Write-Host "Wrote $($outputs.Count) biomes from bedrock-samples@$Ref and updated the Thaw biome list."
