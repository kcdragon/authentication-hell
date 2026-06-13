module ApplicationHelper
  def avatar_badge(user, size_classes: "h-8 w-8")
    if user.avatar.attached? && user.avatar.blob.persisted? && user.avatar.variable?
      image_tag rails_storage_proxy_path(user.avatar.variant(:nav)),
        alt: user.username, crossorigin: "anonymous",
        class: "#{size_classes} rounded-full object-cover bg-gray-200"
    else
      tag.span user.username.first.upcase,
        class: "flex #{size_classes} items-center justify-center rounded-full bg-gray-200 text-gray-700 font-semibold"
    end
  end
end
