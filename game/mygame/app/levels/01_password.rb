class PasswordLevel < Level
  TARGETS = PasswordCharacter::CLASSES

  REQUIRED_PER_CLASS = 2
  PASSWORD_LENGTH = REQUIRED_PER_CLASS * TARGETS.length

  VALIDATION_ERROR_TICKS = 240

  GROUND_COUNT = 5
  CHAR_START_X = 700
  CHAR_END_X = 5600

  HAZARD_KINDS = [ TotpEnemy, PasskeyEnemy, BufferingEnemy ]
  HAZARD_PITCH = 760

  def number = 1

  def title = "Password Complexity"

  def accent = AMBER

  def dialogue(_frame)
    [
      [ "Your company requires passwords with",
        "many different kinds of characters" ],
      [ "Create a password using at least 2 upper case",
        "characters, 2 lower case characters, 2 numbers",
        "and 2 special characters" ]
    ]
  end

  def setup(_frame)
    @platforms = Platform.scatter
    @holes = Hole.scatter
    @collectables = scatter_chars(@platforms)
    @enemies = hazard_enemies(game.player.x)
  end

  def update(frame)
    validate_password(frame) if password_full? && !certificate_spawned?
    @cleared = true if certificate_collected?(frame)
  end

  def all_collected? = TARGETS.all? { |klass| held_count(klass) >= REQUIRED_PER_CLASS }

  def validation_error_active?(frame)
    @validation_error_at && (frame.tick_count - @validation_error_at) < VALIDATION_ERROR_TICKS
  end

  def complete? = @cleared == true

  def next_level = ApiKeyLevel.new(game)

  def draw_hud(frame)
    PASSWORD_LENGTH.times { |slot| draw_password_slot(frame, slot, collected[slot]) }
  end

  def draw(frame)
    lines = if all_collected?
      [ "Password complete —", "head right to finish →" ]
    else
      [ "#{collected_count}/#{PASSWORD_LENGTH} characters" ]
    end
    Caption.new(frame, lines, game).draw
    draw_validation_error(frame) if validation_error_active?(frame)
  end

  private

  SLOT_W = 36
  SLOT_H = 34
  SLOT_X = 24
  SLOT_PITCH = 42
  SLOT_Y = SCREEN_H - 114

  def draw_password_slot(frame, index, glyph)
    klass = glyph && PasswordCharacter.klass_of(glyph)
    face = klass ? PasswordCharacter::CLASS_FACE.fetch(klass) : PAPER
    ink = klass ? PasswordCharacter::CLASS_INK.fetch(klass) : FAINT_INK
    x = SLOT_X + index * SLOT_PITCH
    frame.outputs.solids << { x: x, y: SLOT_Y, w: SLOT_W, h: SLOT_H, r: INK[0], g: INK[1], b: INK[2] }
    frame.outputs.solids << { x: x + 3, y: SLOT_Y + 3, w: SLOT_W - 6, h: SLOT_H - 6,
                             r: face[0], g: face[1], b: face[2] }
    frame.outputs.labels << { x: x + SLOT_W / 2, y: SLOT_Y + SLOT_H / 2 + 1, text: glyph || "·",
                             size_px: 22, font: FONT_MONO_B, r: ink[0], g: ink[1], b: ink[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_validation_error(frame)
    elapsed = frame.tick_count - @validation_error_at
    fade_out = VALIDATION_ERROR_TICKS - LEVEL_INTRO_FADE_OUT
    alpha = (elapsed > fade_out ? 255 * (VALIDATION_ERROR_TICKS - elapsed) / LEVEL_INTRO_FADE_OUT : 255).clamp(0, 255)

    cx = 640
    frame.outputs.labels << { x: cx, y: 470, text: "INVALID PASSWORD",
                             size_px: 30, font: FONT_MONO_B,
                             r: RED[0], g: RED[1], b: RED[2], a: alpha,
                             anchor_x: 0.5, anchor_y: 0.5 }
    frame.outputs.solids << { x: cx - 150, y: 448, w: 300, h: 4,
                             r: RED[0], g: RED[1], b: RED[2], a: alpha }
    frame.outputs.labels << { x: cx, y: 426, text: "need 2 upper · 2 lower · 2 number · 2 symbol — try again",
                             size_px: 16, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2], a: alpha,
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  def password_full? = collected_count >= PASSWORD_LENGTH

  def validate_password(frame)
    all_collected? ? spawn_exit_certificate : fail_validation(frame)
  end

  def fail_validation(frame)
    @collectables.each { |c| c.alive = true if c.is_a?(PasswordCharacter) }
    @validation_error_at = frame.tick_count
  end

  def collected
    @collectables.select { |c| c.is_a?(PasswordCharacter) && !c.alive? }
                 .sort_by(&:pickup_order)
                 .map(&:glyph)
  end

  def held_count(klass) = collected.count { |g| PasswordCharacter.klass_of(g) == klass }

  def collected_count = collected.size

  def scatter_chars(platforms)
    spots = ground_spots + platform_spots(platforms)
    classes = shuffled_classes(spots.length)
    spots.map.with_index do |(x, y), i|
      PasswordCharacter.new(x: x, y: y, klass: classes[i])
    end
  end

  def shuffled_classes(count)
    seeded = TARGETS.flat_map { |klass| [ klass ] * REQUIRED_PER_CLASS }
    extra = [ count - seeded.length, 0 ].max.times.map { TARGETS.sample }
    (seeded + extra).shuffle
  end

  def ground_spots
    pitch = (CHAR_END_X - CHAR_START_X) / (GROUND_COUNT - 1)
    GROUND_COUNT.times.map { |i| [ CHAR_START_X + i * pitch, GROUND_Y ] }
  end

  def platform_spots(platforms)
    platforms.select(&:holds_password).map { |plat| [ plat.x + (plat.w - PasswordCharacter::SIZE) / 2, plat.y + plat.h ] }
  end

  def hazard_enemies(player_x)
    start = player_x + Enemy::SAFE_GAP
    count = ((CHAR_END_X - start) / HAZARD_PITCH).to_i + 1
    count.times.map do |i|
      HAZARD_KINDS[i % HAZARD_KINDS.length].new(x: start + i * HAZARD_PITCH, level: self)
    end
  end
end
