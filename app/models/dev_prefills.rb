module DevPrefills
  def self.enabled? = Rails.env.development? && ENV["DISABLE_DEV_PREFILLS"].blank?
end
