if Rails.env.production?
  Honeybadger.configure do |config|
    config.api_key = Rails.application.credentials.dig(:honeybadger, :api_key)
    config.env = Rails.env

    # This is an auth app — never ship credentials/2FA material to Honeybadger.
    # Mirror config/initializers/filter_parameter_logging.rb.
    config.request.filter_keys = [
      /passw/i, /secret/i, /token/i, /_key/i, /crypt/i, /salt/i,
      /otp/i, /totp/i, /recovery/i, /cvv/i, /cvc/i, /ssn/i, :email
    ]
  end
end
