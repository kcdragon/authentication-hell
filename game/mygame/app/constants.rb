# Scene dimensions shared between main.rb, the entities (player, enemy), and the
# levels. Kept in their own file so the unit tests can load that code — which
# references these at runtime — without booting the engine (main.rb is engine-only).
WORLD_W = 6400  # five screens wide; the viewport scrolls across it
GROUND_Y = 100  # y of the ground line the player and enemies stand on

# The viewport the world scrolls under.
SCREEN_W = 1280
SCREEN_H = 720

# ── HARD MODE visual system ─────────────────────────────────────────────────
# The game is re-skinned to read as an embedded corporate-training *video player*
# (see game/README-video-player.md). Palette + chrome layout live here so the
# values stay in one place; only main.rb (engine-only) consumes them for drawing.
# DragonRuby is bottom-left origin, so y grows upward — the control bar sits at
# the bottom (y 0..GROUND_Y) and the world scrolls above it.

# Palette (the site's neo-brutalist tokens). Each is [r, g, b].
PAPER       = [ 245, 242, 233 ] # background wall
INK         = [ 20, 20, 23 ]    # true-black accents (play button border)
INDIGO      = [ 34, 26, 64 ]    # video chrome: control bar, platform ink, dim
INDIGO_LIP  = [ 61, 53, 99 ]    # floor lip / scrubber track
MUTED       = [ 91, 87, 80 ]    # buffered bar, secondary hint text
FAINT_INK   = [ 201, 196, 187 ] # game-over subline
CARD        = [ 255, 255, 255 ] # platform face
# Semantic role colors (mirror the site; keep distinct).
BLUE        = [ 47, 107, 255 ]  # play / primary
GREEN       = [ 22, 163, 74 ]   # progress fill
RED         = [ 229, 52, 42 ]   # lives / ended accent
PURPLE      = [ 139, 92, 246 ]  # TOTP
AMBER       = [ 245, 166, 35 ]  # password
# Label text inks.
TS_INK      = [ 233, 224, 203 ] # timestamp on the dark bar

# Video-player chrome geometry. The control bar's top edge is the floor line, so
# the bar fills the band below GROUND_Y; its lip sits exactly on GROUND_Y.
BAR_TOP        = GROUND_Y        # floor line / top of the control bar
SCRUBBER_X     = 48
SCRUBBER_W     = SCREEN_W - 2 * SCRUBBER_X
SCRUBBER_Y     = 56              # scrubber track baseline, within the bar band
SCRUBBER_H     = 9
CONTROLS_Y     = 16              # play/pause + timestamp row, within the bar band
VIDEO_SECONDS  = 200             # fake runtime the timestamp counts toward (3:20)

# The play/pause button hit box — the one wired transport control (clicking it
# pauses/resumes). Geometry matches the glyph drawn in main.rb's draw_transport.
PLAY_BUTTON = { x: SCRUBBER_X, y: CONTROLS_Y, w: 34, h: 34 }.freeze

# Fonts (ttf, in mygame/fonts/ — converted from the site's self-hosted woff2).
# Lowercase-kebab filenames (matching the site's woff2 names) so the case-
# sensitive WASM asset lookup resolves cross-platform.
FONT_DISPLAY = "fonts/archivo-black-400.ttf"
FONT_MONO    = "fonts/space-mono-400.ttf"
FONT_MONO_B  = "fonts/space-mono-700.ttf"
