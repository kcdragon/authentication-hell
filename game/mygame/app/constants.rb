WORLD_W = 6400
WORLD_H = 2160
GROUND_Y = 100

SCREEN_W = 1280
SCREEN_H = 720

HOLE_FALL_LIMIT   = -120
HOLE_RESPAWN_BACK = 170

PAPER       = [ 245, 242, 233 ]
INK         = [ 20, 20, 23 ]
INDIGO      = [ 34, 26, 64 ]
INDIGO_LIP  = [ 61, 53, 99 ]
MUTED       = [ 91, 87, 80 ]
FAINT_INK   = [ 201, 196, 187 ]
CARD        = [ 255, 255, 255 ]
# Semantic roles must mirror the site's HTML: BLUE passkey/primary, GREEN progress,
# RED lives/error, PURPLE TOTP, AMBER password. Keep them distinct.
BLUE        = [ 47, 107, 255 ]
GREEN       = [ 22, 163, 74 ]
RED         = [ 229, 52, 42 ]
PURPLE      = [ 139, 92, 246 ]
AMBER       = [ 245, 166, 35 ]
TEAL        = [ 13, 148, 136 ]
RUBY        = [ 155, 17, 30 ]
TS_INK      = [ 233, 224, 203 ] # timestamp ink on the dark control bar

BAR_TOP        = GROUND_Y
SCRUBBER_X     = 48
SCRUBBER_W     = SCREEN_W - 2 * SCRUBBER_X
SCRUBBER_Y     = 56
SCRUBBER_H     = 9
CONTROLS_Y     = 16
LEVEL_TIME_LIMIT = 120

PLAY_BUTTON = { x: SCRUBBER_X, y: CONTROLS_Y, w: 34, h: 34 }.freeze

CC_BUTTON = { x: SCREEN_W - SCRUBBER_X - 150, y: CONTROLS_Y, w: 38, h: 30 }.freeze

SOLID_TRIANGLE_SOURCE = { source_x: 0, source_y: 0, source_x2: 0, source_y2: 1, source_x3: 1, source_y3: 0 }.freeze

# CAPTION_W keeps the caption card's left edge (640 - W/2 = 360) clear of the
# top-left HUD, which reaches ~x 344.
CAPTION_W      = 560
CAPTION_LINE_H = 34
CAPTION_PAD    = 14
CAPTION_MARGIN = 26

LEVEL_INTRO_TICKS    = 110
LEVEL_INTRO_FADE_IN  = 18
LEVEL_INTRO_FADE_OUT = 24

TIME_HINT_THRESHOLDS = [ 30, 10 ].freeze
TIME_HINT_TICKS      = 300
REWIND_FLASH_TICKS   = 90

# Lowercase-kebab ttf filenames: the WASM asset lookup is case-sensitive.
FONT_DISPLAY = "fonts/archivo-black-400.ttf"
FONT_MONO    = "fonts/space-mono-400.ttf"
FONT_MONO_B  = "fonts/space-mono-700.ttf"
