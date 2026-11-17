import { system, world } from "@minecraft/server";
import { SNOWFALL_BIOMES, SNOWFALL_TAG } from "./biomes.js";

// How far from each player the thaw reaches, in blocks.
const RADIUS = 48;
// How many spots are checked around each player every time the thaw runs.
const SPOTS_PER_RUN = 16;
// How often the thaw runs, in ticks (20 ticks = 1 second).
const INTERVAL_TICKS = 2;
// With these numbers every spot near a player is checked about once a minute,
// so an area is almost completely thawed after ~5 minutes of someone being nearby.

const PREFIX = "§bSnowfall Thaw:§r ";

// Players already told that Snowfall is still turned on (once per session is enough).
const warnedPlayers = new Set();

world.afterEvents.playerSpawn.subscribe(({ player, initialSpawn }) => {
  if (initialSpawn) {
    player.sendMessage(PREFIX + "Snow and ice from Snowfall will melt around you. Turn this pack off once spring has arrived.");
  }
});

system.runInterval(() => {
  for (const player of world.getAllPlayers()) {
    const dimension = player.dimension;
    if (dimension.id !== "minecraft:overworld") continue;

    const { x, z } = player.location;
    for (let i = 0; i < SPOTS_PER_RUN; i++) {
      const spotX = Math.floor(x + (Math.random() * 2 - 1) * RADIUS);
      const spotZ = Math.floor(z + (Math.random() * 2 - 1) * RADIUS);
      if (thawSpot(dimension, spotX, spotZ) === "snowfall-still-on") {
        warnSnowfallStillOn(player);
        break;
      }
    }
  }
}, INTERVAL_TICKS);

/**
 * Melts the highest block at x/z if it's leftover snow or ice.
 * Only the highest block is touched, so anything under a roof is safe.
 */
function thawSpot(dimension, x, z) {
  try {
    const block = dimension.getTopmostBlock({ x, z });
    if (!block) return;

    const isIce = block.typeId === "minecraft:ice";
    const isSnow = block.typeId === "minecraft:snow_layer";
    if (!isIce && !isSnow) return;

    // Frozen oceans, snowy tundras and other naturally cold biomes keep their ice and snow.
    const biome = dimension.getBiome(block.location);
    if (!SNOWFALL_BIOMES.has(biome.id)) return;
    if (biome.hasTags([SNOWFALL_TAG])) return "snowfall-still-on";

    if (isSnow) {
      block.setType("minecraft:air");
    } else {
      // Ice that formed on water turns back into water. Ice with nothing under it just disappears.
      const below = block.below();
      block.setType(below && !below.isAir ? "minecraft:water" : "minecraft:air");
    }
  } catch {
    // The spot is in an unloaded chunk or outside the world. It'll be picked again later.
  }
}

function warnSnowfallStillOn(player) {
  if (warnedPlayers.has(player.id)) return;
  warnedPlayers.add(player.id);
  player.sendMessage(PREFIX + "Snowfall is still turned on in this world, so nothing will melt. Turn Snowfall off in the world's behavior packs, then reload the world.");
}
