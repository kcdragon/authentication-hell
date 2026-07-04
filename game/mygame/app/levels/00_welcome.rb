class WelcomeLevel < Level
  ENEMY_SPEED = 3

  def number = 0

  def title = "Welcome"

  def world_w = SCREEN_W

  def start_x = 200

  def initialize(game = nil)
    super
    @combat_spawned = false
    @certificate_dropped = false
  end

  def setup(_args)
    @enemies = []
    @collectables = []
    @holes = []
    @platforms = [
      Platform.new(x: 360, y: Platform::TIERS.first - Platform::H, w: 180, h: Platform::H)
    ]
  end

  def update(args)
    if game.player.reached_platform && @enemies.empty? && !@combat_spawned
      enemy = TutorialEnemy.new(x: game.camera_x + SCREEN_W, level: self)
      enemy.march_left(ENEMY_SPEED)
      @enemies = [ enemy ]
    elsif healed? && !@combat_spawned
      enemy = PasswordEnemy.new(x: game.camera_x - Enemy::WIDTH, level: self)
      enemy.march_right(ENEMY_SPEED, max: world_w)
      @enemies = [ enemy ]
      @combat_spawned = true
    end

    if @combat_spawned && @enemies.none?(&:alive) &&
       !game.player.locked && !game.player.game_over && !@certificate_dropped
      x = (game.player.x + 180).clamp(0, world_w - Certificate::SIZE)
      @collectables << Certificate.new(x: x)
      @certificate_dropped = true
    end

    @cleared = true if certificate_collected?(args)
  end

  def on_unlock(_args)
    x = (game.player.x + 220).clamp(0, world_w - HeartPickup::SIZE)
    @collectables << HeartPickup.new(x: x, y: GROUND_Y + HeartPickup::LIFT)
  end

  def complete? = @cleared == true

  def next_level = PasswordLevel.new(game)

  DIALOGUE_DELAY = 36

  def dialogue(args) = beats(args).map { |_ready, lines| lines }

  def dialogue_hides_scene? = false

  def dialogue_ready?(args)
    i = @dialogue_index.to_i
    return false unless beats(args)[i]&.first == true
    return true if i.zero?

    (@beat_ready_at ||= {})[i] ||= args.state.tick_count
    args.state.tick_count - @beat_ready_at[i] >= DIALOGUE_DELAY
  end

  private

  def healed? = @collectables.any? { |c| c.is_a?(HeartPickup) && !c.alive? }

  def beats(_args)
    player = game.player
    [
      [ true,                                          [ "Move with A / D or arrow keys" ] ],
      [ player.moved,                                  [ "Press Space to jump onto the ledge" ] ],
      [ player.reached_platform,                       [ "Run into the enemy",
                                                         "to learn the re-auth →" ] ],
      [ @collectables.any?(&:alive?),                  [ "Grab the heart to heal" ] ],
      [ healed?,                                       [ "Fight back — jump on its head",
                                                         "to stomp it",
                                                         "← Defeat the enemy on the left" ] ],
      [ @certificate_dropped,                          [ "Grab your certificate",
                                                         "to finish →" ] ]
    ]
  end
end
