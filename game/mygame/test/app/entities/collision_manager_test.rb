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

  def test_fires_once_per_contact_not_every_frame
    a = Rect.new(x: 0)
    b = Rect.new(x: 5)
    resolve(a, b)
    resolve(a, b) # still overlapping — no new alert
    assert_equal 1, a.alerts.length
  end

  def test_a_fresh_contact_after_separating_alerts_again
    a = Rect.new(x: 0)
    b = Rect.new(x: 5)
    resolve(a, b)          # contact
    b.x = 100
    resolve(a, b)          # apart
    b.x = 5
    resolve(a, b)          # touching again
    assert_equal 2, a.alerts.length
  end

  def test_refreshing_the_registry_keeps_a_resting_overlap_from_re_firing
    a = Rect.new(x: 0)
    b = Rect.new(x: 5)
    resolve(a, b)          # reset + add happen inside; edge recorded
    resolve(a, b)          # reset again, same pair still resting
    assert_equal 1, a.alerts.length, "reset empties the set but not the edge state"
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
    enemy = TotpEnemy.new(x: player.x) # bodies overlap; feet on the ground → side hit
    @manager.add(enemy)
    @manager.add(player)
    @manager.resolve(build_args(player: player, tick_count: 0))

    refute enemy.alive
    assert_equal Player::MAX_HEARTS - 1, player.hearts
    assert player.locked
  end

  def test_a_stomp_defeats_the_enemy_and_bounces_the_player
    player = Player.new
    enemy = PasswordEnemy.new(x: player.x)
    player.y = enemy.y + enemy.h - 6 # descending onto its head
    player.vy = -5
    player.grounded = false
    args = build_args(player: player)
    @manager.add(enemy)
    @manager.add(player)
    @manager.resolve(args)

    refute enemy.alive
    assert_equal 1, args.state.kills
    assert_equal Player::STOMP_BOUNCE, player.vy
    assert_equal Player::MAX_HEARTS, player.hearts
  end
end
