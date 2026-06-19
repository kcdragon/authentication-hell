# The collection level the welcome level hands off to: build a password. The world is
# strewn with password padlocks, each carrying one character class (uppercase,
# lowercase, digit, symbol); walking into one is friendly — it collects that
# character (no heart loss, no re-auth). The danger is the *other* auth enemies
# (TOTP, passkey) still patrolling the floor, which cost a heart and a re-auth as
# usual. The completion certificate only appears at the right exit once all four classes
# are held, so the player has to sweep the world before heading there to finish.
class PasswordLevel < Level
  TARGETS = PasswordCharacter::CLASSES

  # The company's "complexity" rule: at least this many of each character class, so
  # finishing means collecting REQUIRED_PER_CLASS * TARGETS.length padlocks in all.
  REQUIRED_PER_CLASS = 2

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

  def title = "Password Complexity"

  def accent = AMBER

  # The HR onboarding spiel the player dismisses (press E) before the level begins.
  def dialogue(_args)
    [
      [ "Your company requires passwords with",
        "many different kinds of characters" ],
      [ "Create a password using at least 2 upper case",
        "characters, 2 lower case characters, 2 numbers",
        "and 2 special characters" ]
    ]
  end

  def setup(args)
    args.state.player.collected_password_characters = {}
    args.state.platforms = Platform.scatter
    args.state.holes = Hole.scatter
    args.state.collectables = scatter_chars(args.state.platforms)
    args.state.enemies = hazard_enemies(args.state.player.x)
  end

  # Once every class is collected, drop the certificate at the right exit (so the player
  # can't finish empty-handed — grabbing it early can't soft-lock since it isn't there
  # yet). Latch completion when they pick it up (#complete? runs without args).
  def update(args)
    if all_collected?(args) && !@certificate_spawned
      args.state.collectables << certificate_at_exit
      @certificate_spawned = true
    end
    @cleared = true if certificate_collected?(args)
  end

  def all_collected?(args) = TARGETS.all? { |klass| held_count(args, klass) >= REQUIRED_PER_CLASS }

  def complete? = @cleared == true

  def next_level = MainLevel.new

  # Non-nil tells the tick to draw the collected-character HUD tray by the hearts.
  def password_targets = TARGETS

  def password_required_per_class = REQUIRED_PER_CLASS

  # Prod the player to sweep up the characters, then flip to "head right" once the
  # set is complete — shown as the top closed caption, updating on each pickup.
  def draw(args)
    lines = if all_collected?(args)
      [ "Password complete —", "head right to finish →" ]
    else
      [ "#{collected_total(args)}/#{TARGETS.length * REQUIRED_PER_CLASS} characters" ]
    end
    Caption.new(args, lines).draw
  end

  private

  # How many of a class the player holds, and the running total toward the goal
  # (each class capped at REQUIRED_PER_CLASS so over-collecting doesn't read as >8).
  def held_count(args, klass) = (args.state.player.collected_password_characters[klass] || []).size

  def collected_total(args) = TARGETS.sum { |klass| [ held_count(args, klass), REQUIRED_PER_CLASS ].min }

  # A ground row plus one padlock on each staircase top, classes cycled (sorted by x) so
  # each appears several times — completing the set means climbing, not just strolling.
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
    platforms.select(&:holds_password).map { |plat| [ plat.x + (plat.w - PasswordCharacter::SIZE) / 2, plat.y + plat.h ] }
  end

  def hazard_enemies(player_x)
    start = player_x + Enemy::SAFE_GAP
    count = ((CHAR_END_X - start) / HAZARD_PITCH).to_i + 1
    count.times.map do |i|
      HAZARD_KINDS[i % HAZARD_KINDS.length].new(x: start + i * HAZARD_PITCH)
    end
  end
end
