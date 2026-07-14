module ApplicationHelper
  def avatar_badge(user, size_classes: "h-8 w-8")
    if user.avatar.attached? && user.avatar.blob.persisted? && user.avatar.variable?
      image_tag rails_storage_proxy_path(user.avatar.variant(:nav)),
        alt: user.username, crossorigin: "anonymous",
        class: "#{size_classes} rounded-[3px] border-2 border-ink object-cover bg-card"
    else
      tag.span user.username.first.upcase,
        class: "grid #{size_classes} place-items-center rounded-[3px] border-2 border-ink bg-password font-display text-sm text-ink"
    end
  end

  def mobile_warning_text
    "Authentication Hell plays best on a desktop with a keyboard — the game may be " \
      "cramped and hard to control on a small screen."
  end

  def dev_prefills_enabled? = DevPrefills.enabled?
end
