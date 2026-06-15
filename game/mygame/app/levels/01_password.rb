# The collection level the tutorial hands off to: build a password. The world is
# strewn with password padlocks, each carrying one character class (uppercase,
# lowercase, digit, symbol); walking into one is friendly — it collects that
# character (no heart loss, no re-auth). The danger is the *other* auth enemies
# (TOTP, passkey) still patrolling the floor, which cost a heart and a re-auth as
# usual. The right wall only finishes the level once all four classes are held, so
# the player has to sweep the world before heading for the exit.
class PasswordLevel < Level
  TARGETS = PasswordCharacter::CLASSES

  # Padlocks spread across the world, cycling the four classes so each appears
  # several times ("full of password enemies"). A row sits on the ground; the rest
  # perch on the platforms, so the player has to climb to finish the set. The ground
  # row is kept clear of the right wall so the last one isn't right at the exit.
  GROUND_COUNT = 5
  CHAR_START_X = 700
  CHAR_END_X = 5600

  # The hazards: TOTP/passkey patrols cycling the floor, the first a safe gap past
  # the player's start so nothing can collide on load. No password enemies — those
  # are collectables here.
  HAZARD_KINDS = [ TotpEnemy, PasskeyEnemy ]
  HAZARD_PITCH = 760

  def number = 1

  def setup(args)
    args.state.player.x = 0
    args.state.player.collected_password_characters = {}
    args.state.camera_x = 0
    args.state.platforms = Platform.scatter
    args.state.collectables = scatter_chars(args.state.platforms)
    args.state.enemies = hazard_enemies(args.state.player.x)
  end

  # Latch completion only once every class is collected *and* the player has reached
  # the far wall (#complete? runs without args, so the check lives here).
  def update(args)
    @cleared = true if all_collected?(args) && reached_end?(args)
  end

  def all_collected?(args) = TARGETS.all? { |klass| args.state.player.collected_password_characters.key?(klass) }

  def complete? = @cleared == true

  def next_level = MainLevel.new

  # Non-nil tells the tick to draw the collected-character HUD tray by the hearts.
  def password_targets = TARGETS

  # Prod the player to sweep up the characters, then flip to "head right" once the
  # set is complete — shown as the top closed caption, updating on each pickup.
  def draw(args)
    lines = if all_collected?(args)
      [ "Password complete —", "head right to finish →" ]
    else
      [ "Grab the padlocks", "#{args.state.player.collected_password_characters.size}/#{TARGETS.length} character types" ]
    end
    Caption.new(args, lines).draw
  end

  private

  # A ground row plus one padlock perched on every platform top, classes cycled
  # across the lot (sorted by x) so each appears several times and is spread between
  # the floor and the ledges — completing the set means climbing, not just strolling.
  def scatter_chars(platforms)
    spots = ground_spots + platform_spots(platforms)
    spots.sort_by { |x, _y| x }.map.with_index do |(x, y), i|
      PasswordCharacter.new(x: x, y: y, klass: TARGETS[i % TARGETS.length])
    end
  end

  def ground_spots
    pitch = (CHAR_END_X - CHAR_START_X) / (GROUND_COUNT - 1)
    GROUND_COUNT.times.map { |i| [ CHAR_START_X + i * pitch, GROUND_Y ] }
  end

  def platform_spots(platforms)
    platforms.map { |plat| [ plat.x + (plat.w - PasswordCharacter::SIZE) / 2, plat.y + plat.h ] }
  end

  def hazard_enemies(player_x)
    start = player_x + Enemy::SAFE_GAP
    count = ((CHAR_END_X - start) / HAZARD_PITCH).to_i + 1
    count.times.map do |i|
      HAZARD_KINDS[i % HAZARD_KINDS.length].new(x: start + i * HAZARD_PITCH)
    end
  end
end
