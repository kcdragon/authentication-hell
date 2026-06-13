# Scene dimensions shared between main.rb, the entities (player, enemy), and the
# levels. Kept in their own file so the unit tests can load that code — which
# references these at runtime — without booting the engine (main.rb is engine-only).
WORLD_W = 6400  # five screens wide; the viewport scrolls across it
GROUND_Y = 100  # y of the ground line the player and enemies stand on

# The viewport the world scrolls under.
SCREEN_W = 1280
SCREEN_H = 720
