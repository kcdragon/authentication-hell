if Rails.env.production?
  Airbrake.configure do |config|
    config.project_id  = Rails.application.credentials.dig(:airbrake, :project_id)
    config.project_key = Rails.application.credentials.dig(:airbrake, :project_key)
    config.environment = Rails.env

    # This is an auth app — never ship credentials/2FA material to Airbrake.
    # Mirror config/initializers/filter_parameter_logging.rb.
    config.blocklist_keys = [
      /passw/i, /secret/i, /token/i, /_key/i, /crypt/i, /salt/i,
      /otp/i, /totp/i, /recovery/i, /cvv/i, /cvc/i, /ssn/i, :email
    ]
  end
end
