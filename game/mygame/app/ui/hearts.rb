class Ui::Hearts
  def initialize(args, hearts)
    @args = args
    @hearts = hearts
  end

  def draw
    Player::MAX_HEARTS.times do |i|
      have = i < @hearts
      @args.outputs.sprites << { x: 24 + i * 42,
                                 y: SCREEN_H - 60,
                                 w: 36,
                                 h: 33,
                                 path: have ? "sprites/ui/heart_hardmode.png" : "sprites/ui/heart_empty.png" }
    end
  end
end
