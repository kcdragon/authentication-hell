# Scene dimensions shared between main.rb and the entities (player, enemy). Kept
# in their own file so the unit tests can load the entities — which reference
# these at runtime — without booting the engine (main.rb is engine-only).
WORLD_W = 6400  # five screens wide; the viewport scrolls across it
GROUND_Y = 100  # y of the ground line the player and enemies stand on
