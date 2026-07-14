class Ui::Transport
  def initialize(frame, game)
    @frame = frame
    @game = game
  end

  def draw
    bx = PLAY_BUTTON[:x]
    by = PLAY_BUTTON[:y]
    draw_play_button(bx, by) unless @game.intro_active?

    limit = @game.level.time_limit
    elapsed = @game.progress * limit
    ink = rewound_recently? ? GREEN : TS_INK
    @frame.outputs.labels << { x: bx + 48, y: by + 26,
                              text: "#{timecode(elapsed)} / #{timecode(limit)}",
                              size_px: 22, font: FONT_MONO,
                              r: ink[0], g: ink[1], b: ink[2],
                              anchor_x: 0, anchor_y: 1 }

    draw_captions(by)

    @frame.outputs.labels << { x: SCREEN_W - SCRUBBER_X, y: by + 26, text: "1.0×   ⛶",
                              size_px: 20, font: FONT_MONO,
                              r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2],
                              anchor_x: 1, anchor_y: 1 }
  end

  private

  def draw_play_button(bx, by)
    @frame.outputs.sprites << { path: :solid, **PLAY_BUTTON, r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    playing = @game.started? && !@game.player.game_over &&
              !@game.player.locked && !@game.paused?
    if playing
      @frame.outputs.sprites << { path: :solid, x: bx + 11, y: by + 9, w: 4, h: 16, r: PAPER[0], g: PAPER[1], b: PAPER[2] }
      @frame.outputs.sprites << { path: :solid, x: bx + 19, y: by + 9, w: 4, h: 16, r: PAPER[0], g: PAPER[1], b: PAPER[2] }
    else
      @frame.outputs.sprites << { path: :solid, x: bx + 12, y: by + 9, x2: bx + 12, y2: by + 25,
                                x3: bx + 26, y3: by + 17,
                                r: PAPER[0], g: PAPER[1], b: PAPER[2] }.merge(SOLID_TRIANGLE_SOURCE)
    end
  end

  def draw_captions(by)
    cc_ink = @game.captions_on? ? TS_INK : FAINT_INK
    @frame.outputs.labels << { x: CC_BUTTON[:x], y: by + 26, text: "CC",
                              size_px: 20, font: FONT_MONO,
                              r: cc_ink[0], g: cc_ink[1], b: cc_ink[2],
                              anchor_x: 0, anchor_y: 1 }
    if @game.captions_on?
      @frame.outputs.sprites << { path: :solid, x: CC_BUTTON[:x], y: by + 6, w: 20, h: 2,
                                r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    end
  end

  def rewound_recently?
    last = @game.level.last_rewind_at
    !last.nil? && @frame.tick_count - last < REWIND_FLASH_TICKS
  end

  def timecode(seconds)
    total = seconds.round
    format("%d:%02d", total / 60, total % 60)
  end
end
