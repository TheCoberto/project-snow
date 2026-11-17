# project-snow

**TheCoberto's Snowfall** is a Minecraft Bedrock add-on that turns your world into a winter wonderland. Turn it on for the holidays, then use **Snowfall Thaw** to melt everything away when the season's over.

Requires Minecraft Bedrock **1.26.50** or newer.

## The packs

| Pack | What it does |
| --- | --- |
| `Snowfall BP` | Makes it snow in 33 temperate and cool biomes, so snow piles up and rivers freeze. |
| `Snowfall RP` | Replaces the grass, foliage and birch colors with near-white versions so plants look frosted. |
| `Snowfall Thaw BP` | Gradually melts leftover snow and ice near players after Snowfall is turned off. |

### Snowy biomes

- **Plains and meadows:** plains (heaviest snow), sunflower plains, meadow, cherry grove
- **Forests:** forest, forest hills, flower forest, dappled forest, all four birch forests, both dark forests, pale garden
- **Taigas:** taiga, taiga hills, taiga mutated, both mega taigas, both redwood taigas
- **Windswept hills:** all five extreme hills biomes
- **Swamps:** swamp, swamp mutated, mangrove swamp
- **Water edges:** river, beach, stone beach

Hot, dry and ocean biomes (desert, badlands, savanna, jungle, oceans, mushroom fields) stay as they are.

## Using it

### Starting winter
1. Import the packs by opening the `.mcpack` / `.mcaddon` files.
2. Turn on **Snowfall** in the world's behavior packs. The resource pack is turned on automatically.

### Ending winter
1. Turn **Snowfall** off in the world's behavior and resource packs.
2. Turn on **Snowfall Thaw** and load the world. It doesn't need Beta APIs or any other experiments.
3. Walk around your base. Snow and ice open to the sky melt around you, and an area is mostly clear after about 5 minutes nearby.
4. Turn Thaw off once spring has arrived.

What Thaw melts:
- Only **ice** and **snow layers**. Packed ice, blue ice and full snow blocks are left alone.
- Only blocks **open to the sky**, so ice under a roof or inside a build is safe.
- Only in the biomes Snowfall changed, so frozen oceans and snowy tundras keep their ice.

> Ice you placed **outside** on purpose in one of the biomes above will melt too. Put a roof over it or mine it with Silk Touch first.

If Snowfall is still on, Thaw doesn't melt anything and tells you in chat.

## For developers

The biome files in `Snowfall BP/biomes` are generated, so don't edit them by hand. `tools/update-biomes.ps1` downloads Mojang's vanilla biome files from [bedrock-samples](https://github.com/Mojang/bedrock-samples), changes only the climate, and adds a `snowfall` tag. It also writes Thaw's biome list, so the two packs always match.

To change which biomes snow or how much, edit the list at the top of the script, then run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\update-biomes.ps1
```

Run it again after each Minecraft update so the overrides keep matching vanilla.

When you release, bump the version in each pack's `manifest.json`: the pack name, `header.version`, the module version and Snowfall BP's dependency on the RP. Then build the release files:

```powershell
powershell -ExecutionPolicy Bypass -File tools\package.ps1
```

That writes `dist\Snowfall-<version>.mcaddon` with all three packs. Importing it doesn't turn anything on; players still choose per world. Add `-PerPack` to also get a separate `.mcpack` for each pack, such as Thaw on its own. Double-click a file to import it into Minecraft. The `dist` folder is ignored by Git.

The script works on any add-on repo. It finds the packs and reads the name and version from the behavior pack's manifest:

```powershell
powershell -ExecutionPolicy Bypass -File tools\package.ps1 -Repo ..\stronger-skeletons -OutDir ..\builds
```
