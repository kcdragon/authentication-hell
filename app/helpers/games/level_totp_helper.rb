module Games::LevelTotpHelper
  def level_totp_challenge_toast_id(user)
    dom_id(user, :level_totp_challenge)
  end

  def level_totp_dev_code_toast_id(user)
    dom_id(user, :level_totp_dev_code)
  end
end
