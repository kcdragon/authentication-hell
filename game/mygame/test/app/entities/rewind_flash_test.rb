require_relative "../../test_helper"

class RewindFlashTest < Minitest::Test
  include GameTest

  def flash = RewindFlash.new(x: 300, y: 200, started_at: 100)

  def test_label_matches_the_pickup_reward
    assert_equal "+0:30", RewindFlash::LABEL
  end

  def test_active_until_the_flash_window_closes
    assert flash.active?(100)
    assert flash.active?(100 + REWIND_FLASH_TICKS - 1)
    refute flash.active?(100 + REWIND_FLASH_TICKS)
  end

  def test_rises_as_it_ages
    assert_equal 0, flash.rise(100)
    assert_equal RewindFlash::RISE, flash.rise(100 + REWIND_FLASH_TICKS)
    assert_operator flash.rise(130), :>, 0
  end

  def test_fades_out_as_it_ages
    assert_equal 255, flash.alpha(100)
    assert_equal 0, flash.alpha(100 + REWIND_FLASH_TICKS)
    assert_operator flash.alpha(130), :<, 255
  end

  def test_render_draws_the_label_in_screen_space
    frame = build_frame(tick_count: 100)

    flash.render(frame, 50, 10)

    label = frame.outputs.labels.fetch(0)
    assert_equal "+0:30", label[:text]
    assert_equal 250, label[:x]
    assert_equal 190, label[:y]
  end
end
