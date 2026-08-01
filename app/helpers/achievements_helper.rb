module AchievementsHelper
  def achievement_icon(achievement, size:, classes: nil)
    if achievement.image? && achievement_image_available?(achievement)
      image_tag achievement.image_path, alt: "", width: size, height: size,
        class: class_names("shrink-0", classes)
    else
      tag.span achievement.emoji, aria: { hidden: true },
        class: class_names("leading-none", classes), style: "font-size: #{size}px"
    end
  end

  private

  def achievement_image_available?(achievement)
    Rails.application.assets.load_path.find(achievement.image_path).present?
  end
end
