require_relative "../../test_helper"

class CollisionManagerTest < Minitest::Test
  include GameTest

  # A minimal collidable: the manager only needs x/y/w/h + on_collision, so a plain
  # rect double stands in for any entity and proves the manager is type-agnostic. It
  # records who it was alerted about so we can count the alerts.
  class Rect
    attr_accessor :x, :y, :w, :h, :alerts

    def initialize(x:, y: 0, w: 10, h: 10)
      @x = x
      @y = y
      @w = w
      @h = h
      @alerts = []
    end

    def on_collision(other, _args) = @alerts << other
  end

  def setup
    @manager = CollisionManager.new
  end

  def resolve(*objects)
    @manager.reset
    objects.each { |o| @manager.add(o) }
    @manager.resolve(build_args)
  end

  def test_alerts_both_objects_of_an_overlapping_pair
    a = Rect.new(x: 0)
    b = Rect.new(x: 5) # overlaps a (0..10 vs 5..15)
    resolve(a, b)
    assert_equal [ b ], a.alerts
    assert_equal [ a ], b.alerts
  end

  def test_leaves_disjoint_objects_alone
    a = Rect.new(x: 0)
    b = Rect.new(x: 100)
    resolve(a, b)
    assert_empty a.alerts
    assert_empty b.alerts
  end

  def test_fires_every_frame_while_overlapping
    a = Rect.new(x: 0)
    b = Rect.new(x: 5)
    resolve(a, b)
    resolve(a, b) # still overlapping — alerts again (a resting contact must re-settle)
    assert_equal 2, a.alerts.length
  end

  def test_reset_empties_the_registry
    a = Rect.new(x: 0)
    b = Rect.new(x: 5)
    @manager.add(a)
    @manager.add(b)
    @manager.reset
    @manager.resolve(build_args)
    assert_empty a.alerts
  end

  # End-to-end against real entities: both sides react. Enemies are registered before
  # the player (as Main does), so the enemy classifies the contact before the player's
  # reaction mutates the state it reads.
  def test_a_side_hit_defeats_the_enemy_and_docks_the_player
    player = Player.new
    enemy = TotpEnemy.new(x: player.x, level: enemy_level) # bodies overlap; feet on the ground → side hit
    @manager.add(enemy)
    @manager.add(player)
    @manager.resolve(build_args(player: player, tick_count: 0))

    refute enemy.alive
    assert_equal Player::MAX_HEARTS - 1, player.hearts
    assert player.locked
  end

  def test_a_stomp_defeats_the_enemy_and_bounces_the_player
    player = Player.new
    enemy = PasswordEnemy.new(x: player.x, level: enemy_level)
    player.y = enemy.y + enemy.h - 6 # descending onto its head
    player.vy = -5
    player.grounded = false
    args = build_args(player: player)
    @manager.add(enemy)
    @manager.add(player)
    @manager.resolve(args)

    refute enemy.alive
    assert_equal Player::STOMP_BOUNCE, player.vy
    assert_equal Player::MAX_HEARTS, player.hearts
  end

  # Landing on two enemies in one frame stomps both: the first bounce flips @vy positive,
  # but the player must still classify the second as a stomp, not take a hit from it.
  def test_stomping_two_enemies_at_once_defeats_both_without_docking_the_player
    player = Player.new
    e1 = PasswordEnemy.new(x: player.x, level: enemy_level)
    e2 = PasswordEnemy.new(x: player.x, level: enemy_level) # both overlap the player
    player.y = e1.y + e1.h - 6 # descending onto their heads
    player.vy = -5
    player.grounded = false
    @manager.add(e1)
    @manager.add(e2)
    @manager.add(player) # player last, as Main does
    @manager.resolve(build_args(player: player))

    refute e1.alive
    refute e2.alive
    assert_equal Player::MAX_HEARTS, player.hearts
    refute player.locked
    assert_equal Player::STOMP_BOUNCE, player.vy
  end

  # Collectables ride the same path: the player walking over one retires it and applies
  # its effect via the shared Collectable#on_collision.
  def test_a_heart_pickup_heals_and_retires_when_the_player_reaches_it
    player = Player.new
    player.hearts = 1
    heart = HeartPickup.new(x: player.x, y: player.y)
    @manager.add(heart)
    @manager.add(player)
    @manager.resolve(build_args(player: player))

    refute heart.alive?
    assert_equal 2, player.hearts
  end

  def test_a_password_character_retires_and_is_stamped_when_the_player_reaches_it
    player = Player.new
    char = PasswordCharacter.new(x: player.x, klass: :upper, glyph: "Q")
    @manager.add(char)
    @manager.add(player)
    @manager.resolve(build_args(player: player))

    refute char.alive?
    assert char.pickup_order # the level rebuilds the password from stamped, retired padlocks
  end

  def test_a_certificate_retires_when_the_player_reaches_it
    player = Player.new
    cert = Certificate.new(x: player.x, y: player.y)
    @manager.add(cert)
    @manager.add(player)
    @manager.resolve(build_args(player: player))

    refute cert.alive?
    assert_equal Player::MAX_HEARTS, player.hearts # the pickup leaves the player otherwise untouched
  end

  # A descending player overlapping a platform is settled onto it — the manager stays
  # type-agnostic; Player#on_collision owns the landing (the platform is passive).
  def test_settles_a_descending_player_onto_a_platform
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30) # top edge at y = 280
    player = Player.new
    player.x = 200
    player.y = 275 # feet dipped below the top this frame
    player.vy = -10
    player.grounded = false
    player.instance_variable_set(:@prev_y, 285) # was above the top last frame
    @manager.add(platform)
    @manager.add(player)
    @manager.resolve(build_args(player: player))

    assert_equal 280, player.y
    assert_equal 0, player.vy
    assert player.grounded
    assert player.reached_platform
  end
end
