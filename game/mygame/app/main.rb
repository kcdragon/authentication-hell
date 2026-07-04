require "app/requires.rb"

module Main
  def tick(args)
    $game ||= Game.new
    $game.tick(args)
  end
end
